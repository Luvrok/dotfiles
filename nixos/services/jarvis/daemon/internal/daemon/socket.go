package daemon

import (
	"bufio"
	"context"
	"encoding/json"
	"log"
	"net"
	"os"
	"time"

	"jarvis/internal/audio"
)

type client struct {
	out chan []byte
	// the cli, it isn't a menu on screen: answers still get a notification
	cli bool
}

type command struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	CLI  bool   `json:"cli"`
}

func (d *Daemon) serve(ctx context.Context, path string) error {
	// a socket left over from a crash
	if c, err := net.Dial("unix", path); err == nil {
		c.Close()
		log.Fatalf("another jarvis daemon is on %s", path)
	}
	os.Remove(path)
	l, err := net.Listen("unix", path)
	if err != nil {
		return err
	}
	os.Chmod(path, 0o600)
	go func() {
		<-ctx.Done()
		l.Close()
		os.Remove(path)
	}()
	log.Printf("listening on %s", path)
	for {
		conn, err := l.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		go d.handle(conn)
	}
}

func (d *Daemon) handle(conn net.Conn) {
	c := &client{out: make(chan []byte, 256)}
	d.mu.Lock()
	d.clients[c] = true
	d.mu.Unlock()
	done := make(chan struct{})
	go func() {
		defer close(done)
		for b := range c.out {
			conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
			if _, err := conn.Write(b); err != nil {
				return
			}
		}
	}()
	defer func() {
		d.mu.Lock()
		delete(d.clients, c)
		d.mu.Unlock()
		close(c.out)
		<-done
		conn.Close()
	}()

	d.mu.Lock()
	hello := map[string]any{"type": "hello", "version": Version, "character": d.char.ID, "state": d.state}
	d.mu.Unlock()
	d.send(c, hello)
	d.send(c, d.charactersMsg())
	d.refreshSources()
	d.send(c, d.sourcesMsg())
	d.send(c, d.loadedMsg())
	d.send(c, d.clonesMsg())

	sc := bufio.NewScanner(conn)
	sc.Buffer(make([]byte, 64*1024), 64*1024)
	for sc.Scan() {
		var cmd command
		if err := json.Unmarshal(sc.Bytes(), &cmd); err != nil {
			d.send(c, map[string]any{"type": "error", "code": "bad_command", "message": err.Error()})
			continue
		}
		if cmd.CLI && !c.cli {
			d.mu.Lock()
			c.cli = true
			d.mu.Unlock()
		}
		d.command(c, cmd)
	}
}

func (d *Daemon) command(c *client, cmd command) {
	switch cmd.Type {
	case "listen":
		d.listen()
	case "pause":
		d.pause()
	case "resume":
		d.resume()
	case "stop", "close":
		// the history stays until forget_after_s
		d.stop()
	case "watch":
		// the bar: it follows the state, it isn't a menu on screen
		d.mu.Lock()
		c.cli = true
		d.mu.Unlock()
	case "new_chat":
		d.newChat()
	case "unload":
		go d.unload()
	case "set_clones":
		d.setClones(cmd.ID)
	case "set_source":
		d.setSource(cmd.ID)
	case "set_character":
		d.setCharacter(cmd.ID)
	case "preview_character":
		d.preview(cmd.ID)
	case "last_answer":
		d.mu.Lock()
		q, text, lang := d.last.question, d.last.text, d.last.lang
		d.mu.Unlock()
		d.send(c, map[string]any{"type": "answer", "text": text, "lang": lang, "question": q, "last": true})
	case "check":
		problems := d.check()
		d.send(c, map[string]any{"type": "check", "ok": len(problems) == 0, "problems": problems})
	default:
		d.send(c, map[string]any{"type": "error", "code": "bad_command", "message": "unknown command " + cmd.Type})
	}
}

func (d *Daemon) send(c *client, msg any) {
	b, _ := json.Marshal(msg)
	b = append(b, '\n')
	d.mu.Lock()
	defer d.mu.Unlock()
	if !d.clients[c] {
		return
	}
	select {
	case c.out <- b:
	default:
		// a client that doesn't read misses levels, not the daemon
	}
}

func (d *Daemon) broadcast(msg any) {
	b, _ := json.Marshal(msg)
	b = append(b, '\n')
	d.mu.Lock()
	defer d.mu.Unlock()
	for c := range d.clients {
		select {
		case c.out <- b:
		default:
		}
	}
}

func (d *Daemon) level(v float64, src string) {
	d.broadcast(map[string]any{"type": "level", "value": float64(int(v*100)) / 100, "src": src})
}

// menus on screen: the clients that aren't the cli
func (d *Daemon) viewers() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	n := 0
	for c := range d.clients {
		if !c.cli {
			n++
		}
	}
	return n
}

func (d *Daemon) charactersMsg() map[string]any {
	list := make([]map[string]any, 0, len(d.ids))
	for _, id := range d.ids {
		ch := d.chars[id]
		list = append(list, map[string]any{"id": id, "name": ch.Name, "icon": ch.Icon, "lang": ch.Lang, "cloned": ch.Voice.Speaker == ""})
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	return map[string]any{"type": "characters", "list": list, "selected": d.char.ID}
}

func (d *Daemon) refreshSources() {
	s, err := d.audio.Sources()
	if err != nil {
		log.Printf("sources: %v", err)
		return
	}
	d.mu.Lock()
	d.sources = s
	d.mu.Unlock()
}

func (d *Daemon) sourcesMsg() map[string]any {
	d.mu.Lock()
	defer d.mu.Unlock()
	list := d.sources
	if list == nil {
		list = []audio.Source{}
	}
	return map[string]any{"type": "sources", "list": list, "selected": d.source}
}
