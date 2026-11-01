// notify: the answer as a desktop notification (quickshell's Notifs.qml
// shows it), and the chime. both are programs from PATH
package notify

import (
	"bytes"
	"context"
	"log"
	"os/exec"
	"strings"
	"sync"
)

type Notifier struct {
	mu sync.Mutex
	// the notify-send waiting on the one up, a newer one takes its place
	cancel context.CancelFunc
}

// Show puts up or replaces the jarvis notification, in order: it returns
// once notify-send runs. clicked runs when the user clicks it (its default
// action)
func (n *Notifier) Show(title, body string, clicked func()) {
	n.mu.Lock()
	defer n.mu.Unlock()
	if n.cancel != nil {
		n.cancel()
	}
	ctx, cancel := context.WithCancel(context.Background())
	n.cancel = cancel

	// the stack tag makes Notifs swap it in place instead of piling up
	cmd := exec.CommandContext(ctx, "notify-send",
		"--app-name=jarvis",
		"--hint=string:x-dunst-stack-tag:jarvis",
		"--action=default=stop",
		"--wait",
		title, body)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Start(); err != nil {
		log.Printf("notify-send: %v", err)
		return
	}
	go func() {
		err := cmd.Wait()
		if ctx.Err() != nil {
			return
		}
		if err != nil {
			log.Printf("notify-send: %v", err)
			return
		}
		if strings.TrimSpace(out.String()) == "default" && clicked != nil {
			clicked()
		}
	}()
}

// Chime plays the "answer is ready" sound, in the background
func Chime(path string) {
	if path == "" {
		return
	}
	cmd := exec.Command("pw-play", path)
	if err := cmd.Start(); err != nil {
		log.Printf("pw-play: %v", err)
		return
	}
	go cmd.Wait()
}

// Run starts a command in the background, like the menu's open command
func Run(argv []string) {
	if len(argv) == 0 {
		return
	}
	cmd := exec.Command(argv[0], argv[1:]...)
	if err := cmd.Start(); err != nil {
		log.Printf("%s: %v", argv[0], err)
		return
	}
	go cmd.Wait()
}
