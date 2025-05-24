function initEditor() {
    let ed = document.getElementById("code-editor");
    ed.addEventListener("keydown", (e) => { e.stopPropagation(); });
    ed.addEventListener("keypress", (e) => { e.stopPropagation(); });
    ed.addEventListener("keyup", (e) => { e.stopPropagation(); });

    editor = ace.edit("code-editor", {
        theme: editorTheme,
        mode: "ace/mode/assembly_x86",
        fontSize: "14px",
        showPrintMargin: false,
        //useWorker: false, // optional, to avoid delay due to syntax checking
    });
    editor.setValue(sourceCode, -1);
    editor.setKeyboardHandler("ace/keyboard/vscode");
    editor.focus();
}

function base64ToUint8Array(base64) {
    const binaryString = atob(base64);
    const length = binaryString.length;
    const bytes = new Uint8Array(length);
    
    for (let i = 0; i < length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }

    return bytes;
}

async function runCom() {
    let dosboxConf = `
        [sdl]
        output=overlay
        [cpu]
        core=auto
        cputype=auto
        cycles=100000
        [render]
        vsync=true
        frameskip=0
        [mixer]
        nosound=false
        rate=44100
        blocksize=1024
        prebuffer=25
        [midi]
        mpu401=uart
        mididevice=default
        midiconfig=
        [sblaster]
        sbtype=sb16
        sbbase=220
        irq=7
        dma=1
        hdma=5
        sbmixer=true
        oplmode=auto
        oplemu=default
        oplrate=44100
        [autoexec]
        mount c .
        c:
        dummy.com
    `;
    switchTab('output');
    sourceCode = editor.getValue();
    try {
        setStatus("sending query...");
        let langs = document.getElementById("asm-lang");
        let lang = langs.options[langs.selectedIndex].value.toLowerCase();
        let params = {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ "files": { "dummy.asm": sourceCode }, "lang":"dosasm", "version":"1.0-"+lang })
        };
        const response = await fetch("/api/compile/", params);
        const result = await response.json();

        setStatus("parsing response...");

        if (result.base64) {
            const dummyCom = base64ToUint8Array(result.base64);
            const size = dummyCom.length;

            document.getElementById("dosbox-container").style.display = "block";
            document.getElementById("dosbox-container").tabIndex = 0;
            document.getElementById("compiler-output").style.display = "none";

            setStatus("running emulation");

            Dos(document.getElementById("dosbox-container"), {
                dosboxConf: dosboxConf,
                initFs: [
                    { path: "dummy.com", contents: dummyCom },
                ],
                onEvent: (event, ci) => {
                    if (event === "emu-ready") {
                        setStatus("emulator ready");
                    }
                    if (event === "bnd-play") {
                        setStatus("bundle ready");
                    }
                    if (event === "ci-ready") {
                        setStatus("running program ("+size+" bytes)");
                    }
                },
                autoStart: true,
                kiosk: false,
                backend: "dosboxX"
            });
        } else if (result.output) {
            setStatus("error");
            document.getElementById("dosbox-container").style.display = "none";
            document.getElementById("compiler-output").innerText = result.output;
            document.getElementById("compiler-output").style.display = "block";
        } else {
            setStatus("unexpected response from the server");
            document.getElementById("compiler-output").innerText = "Unexpected response from the server.";
            document.getElementById("compiler-output").style.display = "block";
        }
    } catch (error) {
        setStatus(error.message);
        document.getElementById("compiler-output").innerText = "Failed to compile: " + error.message;
        document.getElementById("compiler-output").style.display = "block";
    }
}

// Resizeable panes ---------------------------------------------------------------------

const resizer = document.getElementById('resizer');
const leftPane = document.getElementById('left-pane');
const rightPane = document.getElementById('right-pane');
const container = document.querySelector('.container');
const codeEditor = editor;
let isResizing = false;

resizer.addEventListener('mousedown', () => {
    isResizing = true;
    document.body.style.cursor = 'ew-resize';
});

document.addEventListener('mousemove', (e) => {
    if (!isResizing) return;
    const containerOffsetLeft = container.offsetLeft;
    const pointerRelativeXpos = e.clientX - containerOffsetLeft;
    const totalWidth = container.offsetWidth;
    const leftWidth = Math.max(200, pointerRelativeXpos);
    const rightWidth = Math.max(200, totalWidth - leftWidth - 5);
    leftPane.style.flex = 'none';
    rightPane.style.flex = 'none';
    leftPane.style.width = `${leftWidth}px`;
    rightPane.style.width = `${rightWidth}px`;
});

document.addEventListener('mouseup', () => {
    if (isResizing) {
    isResizing = false;
    document.body.style.cursor = 'default';
    codeEditor.focus();
    }
});

resizer.addEventListener('dblclick', () => {
    const totalWidth = container.offsetWidth;
    const half = (totalWidth - 5) / 2;
    leftPane.style.flex = 'none';
    rightPane.style.flex = 'none';
    leftPane.style.width = `${half}px`;
    rightPane.style.width = `${half}px`;
    codeEditor.focus();
});

// Tabs switching -----------------------------------------------------------------------

function switchTab(tabId) {
    document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(tc => tc.style.display = 'none');

    document.querySelector(`.tab[onclick*="${tabId}"]`).classList.add('active');
    document.getElementById(`tab-${tabId}`).style.display = 'block';
}

// Examples -----------------------------------------------------------------------------

function formatExamples(examples) {
    let xlat = {"32b":"32 bytes", "64b":"64 bytes", "128b":"128 bytes", "256b":"256 bytes", "512b":"512 bytes", "1k":"1k"};
    examples.forEach(ex => {
        ex.descr = `<span class="size-label">[`+xlat[ex.size]+`]</span> `+ex.descr.replace(/\*(.*?)\*/gi, "<b>$1</b>");
        if (ex.link.length) ex.link = ` [<a href="`+ex.link+`" target=_blank>link</a>]`;
        if (ex.rating) ex.rating = ` rating: `+ex.rating/100;
    });
    return examples;
}

function viewExamples() {
    sz = document.getElementById("size-select").value;
    let list = examples.filter(item => item.size == sz || sz == "*");
    let html = nsTmpl.tmplr("template-example", list);
    document.getElementById("examples-viewport").innerHTML = html;
}

async function loadExample(id) {
    const ex = examples.find(item => item.id == id);
    let response = await fetch(`/examples/${ex.size}/${ex.fname}`);
    if (response.status != 200) return;

    let src = await response.text();
    document.getElementById("asm-lang").value = ex.asm_type;
    editor.setValue(src, -1);
}

// Source control -----------------------------------------------------------------------

function setStatus(str) {
    document.getElementById("asm-status").innerText = str;
}

async function saveSource() {
    const txt = editor.getValue();
    const asm = document.getElementById("asm-lang").value;

    const response = await fetch("/api/save/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ txt: txt, asm_type: asm })
    });

    if (!response.ok) {
        setStatus("Network response was not OK");
        return;
    }

    const data = await response.json();
    if (!data || !data.token) {
        setStatus("JSON read error");
    }

    const newUrl = `${window.location.origin}/${data.token}/`;
    window.history.pushState({}, "", newUrl);

    navigator.clipboard.writeText(newUrl).then(() => {
        // Change button text to "Copied"
        saveButton = document.getElementById("save-button");
        const originalText = saveButton.textContent;
        saveButton.style.width = saveButton.offsetWidth+"px";
        saveButton.textContent = "Copied";
        saveButton.disabled = true;

        // Revert after 1 second
        setTimeout(() => {
            saveButton.textContent = originalText;
            saveButton.style.width = "";
            saveButton.disabled = false;
        }, 1000);
    });
}
