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
const defaultSource = `IDEAL
P386
MODEL TINY
CODESEG
        ORG     100H
Start:

BLOB_X  equ     48
BLOB_Y  equ     48
LONG    equ     31

; video
        mov     ax,0013h
        int     10h
; palette
        mov     dx,3C8h
        xor     ax,ax
        out     dx,al
        inc     dx
        mov     cx,256
@@pal:  mov     ax,256
        sub     ax,cx
        shr     ax,1
        out     dx,al
        shr     ax,1
        out     dx,al
        shr     ax,2
        out     dx,al
        loop    @@pal
; buffer
        mov     ax,cs
        add     ah,10h
        mov     es,ax
        mov     ch,0FAh
        xor     ax,ax
        xor     di,di
        rep     stosw

MainLoop:
; blob
        mov     di,[y]
        shl     di,8
        mov     ax,di
        shr     ax,2
        add     di,ax
        add     di,[x]
        mov     bx,BLOB_Y
@@y:    mov     cx,BLOB_X
@@x:    inc     [byte ptr es:di]
        inc     di
        loop    @@x
        add     di,320-BLOB_X
        dec     bx
        jnz     @@y
; swap to screen
        push    es
        pop     ds
        push    0A000h
        pop     es
        xor     si,si
        xor     di,di
        mov     ch,7Dh
        rep     movsw
        push    ds
        pop     es
        push    cs
        pop     ds
; move
        call    Random
        test    al,LONG
        jnz     @@m1
        neg     [deltax]
@@m1:   mov     ax,[deltax]
        add     [x],ax
        call    Random
        test    al,LONG
        jnz     @@m2
        neg     [deltay]
@@m2:   mov     ax,[deltay]
        add     [y],ax
; key
        mov     ah,1
        int     16h
        jz      MainLoop
; back to DOS
        mov     ax,0003h
        int     10h
        int     16h
        ret

x       dw      100
y       dw      100
deltax  dw      1
deltay  dw      1

proc    Random
        mov     eax,[Seed]
        imul    [RandMul]
        dec     eax
        mov     [Seed],eax
        shr     eax,16
RandMul dd      015A4EC3h ; <-- ret
Seed    dd      1
endp    Random

END     Start
`
