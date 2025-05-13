package service

import "net/http"

func (s *Service) Index(w http.ResponseWriter, r *http.Request) int {
	return 200
}

func (s *Service) About(w http.ResponseWriter, r *http.Request) int {
	return 200
}

func (s *Service) WebRefresh(w http.ResponseWriter, r *http.Request) int {
	return 200
}

func (s *Service) RunProgram(w http.ResponseWriter, r *http.Request) int {
	return 200
}
