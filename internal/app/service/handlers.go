package service

import (
	"bufio"
	"bytes"
	_ "embed"
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
	if err != nil || len(buf) > 20000 { // ~20K source code is enough
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
	indexTemplate, err := template.ParseFiles(path.Join(tmplpath, "index.html"), path.Join(tmplpath, "gtag.js"))
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

type compileRequest struct {
	Lang    string            `json:"lang"`
	Version string            `json:"version"`
	Files   map[string]string `json:"files"`
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
	var req compileRequest

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
	req.CPUs = 12000
	req.CPUTime = 15000
	req.Net = 0
	req.RunTime = 15

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
			event := strings.TrimSpace(line[7:]) // we do not expect any spaces nor newlines in event name, get rid of them.
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

//go:embed default_source.asm
var defaultSource string
