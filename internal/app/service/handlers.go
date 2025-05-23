package service

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/bhmj/goblocks/log"
	"github.com/gorilla/mux"
)

func (s *Service) HandleIndex(w http.ResponseWriter, r *http.Request) (int, error) {
	err := s.index(w, "")
	if err != nil {
		return http.StatusInternalServerError, err
	}
	return http.StatusOK, nil
}

func (s *Service) HandleIndexWithToken(w http.ResponseWriter, r *http.Request) (int, error) {
	params := mux.Vars(r)
	token := params["source_token"]
	err := s.index(w, token)
	if err != nil {
		return http.StatusInternalServerError, err
	}
	return http.StatusOK, nil
}

func (s *Service) HandleSave(w http.ResponseWriter, r *http.Request) (int, error) {
	buf, err := io.ReadAll(r.Body)
	if err != nil {
		return http.StatusBadRequest, err
	}
	return s.ReplyStoredProcedure(w, "api.save_source", string(buf))
}

func (s *Service) ExecuteProcedure(procName string, args ...interface{}) ([]byte, error) {
	var result string
	procArguments := []string{"", "$1", "$1, $2", "$1, $2, $3", "$1, $2, $3, $4", "$1, $2, $3, $4, $5", "$1, $2, $3, $4, $5, $6", "$1, $2, $3, $4, $5, $6, $7"}
	if len(args) > 7 { // nolint:gomnd
		return nil, errors.New("too many arguments for a stored procedure")
	}
	_, err := s.db.QueryRow(&result, fmt.Sprintf("select %s(%s)", procName, procArguments[len(args)]), args...)
	if err != nil {
		return nil, err // nolint:wrapcheck
	}
	return []byte(result), nil
}

func (s *Service) ReplyStoredProcedure(w http.ResponseWriter, procName string, args ...interface{}) (int, error) {
	result, err := s.ExecuteProcedure(procName, args...)
	if err != nil {
		return http.StatusBadRequest, err
	}
	if result != nil {
		return s.replier.ReplyJSON(w, result)
	}
	return s.replier.ReplyNoContent(w)
}

type indexData struct {
	Source   string `db:"txt"`
	AsmType  string `db:"asm_type"`
	Examples string
}

func (s *Service) index(w http.ResponseWriter, token string) error {
	data := indexData{}
	if token != "" {
		found, err := s.db.QueryRow(&data, "select txt, asm_type from public.sources where token = $1", token)
		if err != nil {
			return err //nolint:wrapcheck
		}
		if !found {
			data.Source = "Specified source ID not found"
		}
	} else {
		data.Source = defaultSource
		data.AsmType = defaultAsmType
	}
	if data.AsmType == "" {
		data.AsmType = defaultAsmType
	}

	type exampleRow struct {
		ID       int    `db:"id" json:"id"`
		Filename string `db:"txt_filename" json:"fname"`
		Image    string `db:"image_filename" json:"image"`
		Size     string `db:"size_category" json:"size"`
		AsmType  string `db:"asm_type" json:"asm_type"`
		Descr    string `db:"descr" json:"descr"`
		Link     string `db:"link" json:"link"`
		Rating   int    `db:"rating" json:"rating"`
	}
	var examples []exampleRow
	err := s.db.Query(&examples, "select id, txt_filename, image_filename, size_category, asm_type, descr, link, rating from public.examples")
	if err != nil {
		return err //nolint:wrapcheck
	}
	buf, err := json.Marshal(examples)
	if err != nil {
		return err //nolint:wrapcheck
	}
	data.Examples = string(buf)

	// parse template
	tmplpath, err := filepath.Abs(s.cfg.TemplatesPath)
	if err != nil {
		return err //nolint:wrapcheck
	}
	indexTemplate, err := template.ParseFiles(path.Join(tmplpath, "index.html"))
	if err != nil {
		return err //nolint:wrapcheck
	}
	w.Header().Set("Content-Type", "text/html")
	w.Header().Set("X-Frame-Options", "DENY")
	err = indexTemplate.Execute(w, data)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
	return nil
}

func (s *Service) HandleAbout(w http.ResponseWriter, r *http.Request) int {
	return 200
}

type pgRunRequest struct {
	ComboHandle   string            `json:"idc"`
	SnippetHandle string            `json:"id"`
	Lang          string            `json:"lang"`
	Version       string            `json:"version"`
	Files         map[string]string `json:"files"`
	//
	RAM     uint `json:"ram"`     // Mb
	CPUs    uint `json:"cpus"`    // 1/1000 CPU
	CPUTime uint `json:"cputime"` // ms
	Net     uint `json:"net"`     // bytes
	RunTime uint `json:"runtime"` // sec
}

func (s *Service) HandleCompileCORS(w http.ResponseWriter, r *http.Request) (int, error) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	return s.replier.ReplyOK(w)
}

func (s *Service) HandleCompile(w http.ResponseWriter, r *http.Request) (int, error) {
	var req pgRunRequest

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	rawJson, err := io.ReadAll(r.Body)
	if err != nil {
		return http.StatusBadRequest, err
	}

	err = json.Unmarshal(rawJson, &req)
	if err != nil {
		return http.StatusBadRequest, err
	}

	// update sandbox query with default values for DOS VM
	req.RAM = 300
	req.CPUs = 2000
	req.CPUTime = 5000
	req.Net = 0
	req.RunTime = 5

	// do not pass raw input json, repack
	sandboxReq, err := json.Marshal(&req)
	if err != nil {
		return http.StatusBadRequest, err
	}

	// send request
	request, err := http.NewRequest("POST", s.cfg.PlaygroundServer+"/api/run/", bytes.NewBuffer(sandboxReq))
	if err != nil {
		return http.StatusInternalServerError, err
	}
	request.Header.Set("Api-Token", s.cfg.PlaygroundAPIToken)
	client := &http.Client{}
	resp, err := client.Do(request)
	if err != nil {
		s.logger.Error("client.Do", log.Error(err))
		return http.StatusInternalServerError, err
	}
	defer resp.Body.Close()

	// read response
	buf, err := readSSEStreams(resp, []string{"stdout", "stderr"})
	if err != nil {
		s.logger.Error("readSSEStreams", log.Error(err))
		return http.StatusInternalServerError, err
	}

	// parse response
	file, output, err := parseResponse(buf)

	if err != nil {
		return http.StatusInternalServerError, err
	}

	var result struct {
		Base64 string `json:"base64"`
		Output string `json:"output"`
	}

	if file != "" {
		result.Base64 = file
	} else {
		result.Output = output
	}
	return s.replier.ReplyObject(w, result)
}

func readSSEStreams(r *http.Response, streams []string) (string, error) {
	scanner := bufio.NewScanner(r.Body)

	// replacer restores the original byte sequence.
	// See combobox/internal/app/cman/service/handlers.go:68
	replacer := strings.NewReplacer(`\:`, `:`, `\n`, "\n", `\r`, "\r", `\\`, `\`)

	var data string
	reading := false
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, "event: ") {
			event := strings.TrimSpace(line[7:]) // we do not expect any spaces nor newlines, get rid of them.
			reading = false
			for _, stream := range streams {
				if strings.HasPrefix(event, stream) {
					reading = true // next "data" field must be read
					break
				}
			}
		} else if strings.HasPrefix(line, "data: ") {
			if reading {
				str := replacer.Replace(line[6:])
				data += str
			}
		}
	}
	return data, nil
}

func parseResponse(buf string) (string, string, error) {
	const streamStart = "::STREAM::START"
	const streamFile = "::STREAM::FILE"
	const streamEnd = "::STREAM::END"

	// the buf may contain mixed 'CRLF' or 'LF' line feeds. We want to convert them to Linux style
	buf = strings.ReplaceAll(buf, "\r\n", "\n")

	istart := strings.Index(buf, streamStart)
	if istart == -1 {
		return "", "", errors.New("stream start not found")
	}
	istart += len(streamStart) + 1 // LF

	iend := strings.Index(buf, streamEnd)
	if iend == -1 {
		return "", "", errors.New("stream end not found")
	}

	ifile := strings.Index(buf, streamFile)
	if ifile > 1 {
		// hotfix for random "\r": just cut them out
		buf = buf[ifile+len(streamFile):]
		buf = strings.ReplaceAll(buf, "\r", "")
		buf = strings.ReplaceAll(buf, "\n", "")
		iend = strings.Index(buf, streamEnd)
		return buf[:iend], "", nil
	}

	return "", strings.ReplaceAll(buf[istart:iend], "\r\r", "\r"), nil
}

const defaultAsmType = "TASM"
const defaultSource = `.model small
.386
.code

assume  cs:_TEXT, ds:_TEXT

LEFT_FIELD      equ     60
BOBSIZE         equ     16
COLOR           equ     32

BOBS            equ     17

        org     100h
Start:

; Generate bobs --------------------------------------------
        mov     di,offset Coord
        mov     eax,00100030h
        mov     cx,BOBS
        rep     stosd

        mov     al,13h
        int     10h

; Create buffer --------------------------------------------
        mov     ax,cs
        add     ax,(300h)/16+1
        mov     es,ax
        ; Clear buffer
        xor     di,di
        mov     ch,07Dh         ; CX = 32000
        xor     ax,ax
        rep     stosw           ; CX==0

; Generate palette ------------------------------------------
        mov     dx,3C8h
        out     dx,al
        inc     dx
@@SetPal:
        mov     ax,cx
        shr     ax,1
        out     dx,al   ; R
        out     dx,al   ; G
        shr     ax,1
        out     dx,al   ; B
        inc     cl
        jnz     @@SetPal

; Main loop:
@@Continue:
; MovePoints ---------------------------------------------
        mov     cl,BOBS*2
        lea     si,Step
        lea     di,Coord
        lea     bx,Bounds
@@MP1:
        movsx   ax,[si]                 ; load step
        add     [di],ax                 ; coord[i] += step[i]
        mov     dx,[bx]                 ; load left/top bound
        inc     bx
        inc     bx
        cmp     word ptr [di],dx        ; if coord is out of bound..
        jl      @@MP2                   ; ..negate step
        mov     dx,[bx]                 ; load right/bottom bound
        cmp     word ptr [di],dx        ; if coord is out of bound..
        jle     @@MP3
@@MP2:
        neg     byte ptr [si]
@@MP3:
        dec     bx
        dec     bx
        inc     si
        inc     di
        inc     di
        loop    @@MP1

; Draw ----------------------------------------------------------
        lea     bx,Coord
        mov     cl,BOBS
@@DFor:
        push    cx
        mov     di,[bx]         ; Xi
        add     di,LEFT_FIELD
        mov     ax,[bx+2]       ; Yi
        mov     dx,320
        mul     dx
        add     di,ax

        mov     cl,BOBSIZE
@@D1:   push    cx
        mov     cl,BOBSIZE
@@D2:   mov     al,byte ptr es:[di]
        add     al,COLOR
        jnc     @@D3
        mov     al,0FFh
@@D3:   stosb
        loop    @@D2
        add     di,320-BOBSIZE
        pop     cx
        loop    @@D1

        pop     cx
        add     bx,4            ; !!!
        loop    @@DFor

        push    ds
        push    es

        push    es
        pop     ds
; Fire --------------------------------------------------------
        mov     si,320
        mov     di,si
        mov     cx,64000-320*2
@@F1:
        xor     bx,bx
        mov     bl,byte ptr [si-1]
        mov     ax,bx
        mov     bl,byte ptr [si+1]
        add     ax,bx
        mov     bl,byte ptr [si-320]
        add     ax,bx
        mov     bl,byte ptr [si+320]
        add     ax,bx
        shr     ax,2
        jz      @@F2
        dec     ax
@@F2:   stosb
        inc     si
        loop    @@F1

; CopyScreen ------------------------------------------------
        push    0A000h
        pop     es
        xor     si,si
        xor     di,di
        mov     ch,7Dh          ; CX = 32000
        rep     movsw

        pop     es
        pop     ds

; Check for ESC pressed
        mov     ah,01
        int     16h
        jz      @@Continue

        mov     ax,0003h
        int     10h
        int     16h

        ret

; End of main()

; Data ==============================================

Bounds  label
        dw      15
        dw      320-LEFT_FIELD*2-BOBSIZE-15
Step    label
        db      +2
        db      +6      ; 1
        db      +2
        db      +4      ; 2
        db      +3
        db      +5      ; 3
        db      +4
        db      -4      ; 4
        db      +5
        db      -2      ; 5
        db      +6
        db      -1      ; 6
        db      -1
        db      +7      ; 7
        db      -2
        db      +4      ; 8
        db      -3
        db      +5      ; 9
        db      -4
        db      +3      ; 10
        db      -5
        db      +3      ; 11
        db      -5
        db      -4      ; 12
        db      +2
        db      -6      ; 13
        db      +3
        db      +2      ; 14
        db      +2
        db      -4      ; 15
        db      +3
        db      -3      ; 16
        db      +7
        db      -2      ; 17
Coord   label

end     Start
`
