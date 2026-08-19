package main

import (
	"encoding/json"
	"fmt"
	"os"
)

type pingResponse struct {
	OK      bool   `json:"ok"`
	Version string `json:"version"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "missing command")
		os.Exit(2)
	}

	switch os.Args[1] {
	case "ping":
		if err := json.NewEncoder(os.Stdout).Encode(pingResponse{
			OK:      true,
			Version: "dev",
		}); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unkown command: %s\n", os.Args[1])
		os.Exit(2)
	}
}
