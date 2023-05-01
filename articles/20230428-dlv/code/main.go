package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("hello"))
	})
	log.Printf("listening on :8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
