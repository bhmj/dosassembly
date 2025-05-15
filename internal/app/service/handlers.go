package service

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/bhmj/goblocks/log"
)

func (s *Service) Index(w http.ResponseWriter, r *http.Request) int {
	return 200
}

func (s *Service) About(w http.ResponseWriter, r *http.Request) int {
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

func (s *Service) CompileCORS(w http.ResponseWriter, r *http.Request) int {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	s.replier.ReplyOK(w)
	return http.StatusOK
}

func (s *Service) Compile(w http.ResponseWriter, r *http.Request) int {
	var req pgRunRequest

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	rawJson, err := io.ReadAll(r.Body)
	if err != nil {
		return http.StatusBadRequest
	}

	err = json.Unmarshal(rawJson, &req)
	if err != nil {
		return http.StatusBadRequest
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
		return http.StatusBadRequest
	}

	// send request
	request, err := http.NewRequest("POST", s.cfg.PlaygroundServer+"/api/run/", bytes.NewBuffer(sandboxReq))
	if err != nil {
		return http.StatusInternalServerError
	}
	request.Header.Set("Api-Token", s.cfg.PlaygroundAPIToken)
	client := &http.Client{}
	resp, err := client.Do(request)
	if err != nil {
		s.logger.Error("client.Do", log.Error(err))
		return http.StatusInternalServerError
	}
	defer resp.Body.Close()

	// read response
	buf, err := readSSEStreams(resp, []string{"stdout", "stderr"})
	if err != nil {
		s.logger.Error("readSSEStreams", log.Error(err))
		return http.StatusInternalServerError
	}

	// parse response
	file, output, err := parseResponse(buf)

	if err != nil {
		return http.StatusInternalServerError
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
	s.replier.ReplyJSON(w, result)
	return http.StatusOK
}

func (s *Service) WebRefresh(w http.ResponseWriter, r *http.Request) int {
	return 200
}

func (s *Service) RunProgram(w http.ResponseWriter, r *http.Request) int {
	return 200
}

func readSSEStreams(r *http.Response, streams []string) (string, error) {
	scanner := bufio.NewScanner(r.Body)
	var data string
	replacer := strings.NewReplacer("\\n", "\n", "\\\\", "\\")
	reading := false

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, "event: ") {
			event := strings.TrimSpace(line[7:])
			reading = false
			for _, stream := range streams {
				if strings.HasPrefix(event, stream) {
					reading = true
					break
				}
			}
		} else if strings.HasPrefix(line, "data: ") {
			if reading {
				data += replacer.Replace(line[6:])
			}
		}
	}
	return data, nil
}

func parseResponse(buf string) (string, string, error) {
	const streamStart = "::STREAM::START"
	const streamFile = "::STREAM::FILE"
	const streamEnd = "::STREAM::END"

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
		return buf[ifile+len(streamFile)+3 : iend], "", nil // CR+LF+CR
	}

	return "", strings.ReplaceAll(buf[istart:iend], "\r\r", "\r"), nil
}
