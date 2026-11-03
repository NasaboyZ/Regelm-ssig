package protocol

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
)

const (
	ProtocolVersion uint8 = 1
	MaxTransferID         = 255
	MaxChunks             = 1 << 20
)

type Chunk struct {
	TransferID      string
	ProtocolVersion uint8
	Index           uint32
	Total           uint32
	Salt            []byte
	Nonce           []byte
	CipherText      []byte
	MAC             []byte
	Encrypted       bool
}

func (c Chunk) Bytes() ([]byte, error) {
	if len(c.TransferID) == 0 || len(c.TransferID) > MaxTransferID || len(c.Salt) > 255 || len(c.Nonce) > 255 || len(c.MAC) > 255 {
		return nil, errors.New("invalid transfer metadata length")
	}
	if c.Total == 0 || c.Total > MaxChunks || c.Index >= c.Total {
		return nil, errors.New("invalid transfer index")
	}
	var out bytes.Buffer
	out.Write([]byte{'R', 'G', 'T', '1'})
	out.WriteByte(c.ProtocolVersion)
	if c.Encrypted {
		out.WriteByte(1)
	} else {
		out.WriteByte(0)
	}
	out.WriteByte(byte(len(c.TransferID)))
	out.WriteString(c.TransferID)
	writeUint32(&out, c.Index)
	writeUint32(&out, c.Total)
	out.WriteByte(byte(len(c.Salt)))
	out.Write(c.Salt)
	out.WriteByte(byte(len(c.Nonce)))
	out.Write(c.Nonce)
	if uint64(len(c.CipherText)) > uint64(^uint32(0)) {
		return nil, errors.New("ciphertext is too large")
	}
	writeUint32(&out, uint32(len(c.CipherText)))
	out.Write(c.CipherText)
	out.WriteByte(byte(len(c.MAC)))
	out.Write(c.MAC)
	return out.Bytes(), nil
}

func ParseChunk(input []byte) (Chunk, error) {
	reader := bytes.NewReader(input)
	magic := make([]byte, 4)
	if _, err := io.ReadFull(reader, magic); err != nil || string(magic) != "RGT1" {
		return Chunk{}, errors.New("unknown transfer format")
	}
	version, err := reader.ReadByte()
	if err != nil {
		return Chunk{}, errors.New("truncated transfer chunk")
	}
	flag, err := reader.ReadByte()
	if err != nil || flag > 1 {
		return Chunk{}, errors.New("invalid transfer security mode")
	}
	readSized := func() ([]byte, error) {
		size, err := reader.ReadByte()
		if err != nil {
			return nil, errors.New("truncated transfer chunk")
		}
		value := make([]byte, int(size))
		if _, err := io.ReadFull(reader, value); err != nil {
			return nil, errors.New("truncated transfer chunk")
		}
		return value, nil
	}
	idBytes, err := readSized()
	if err != nil || len(idBytes) == 0 || len(idBytes) > MaxTransferID {
		return Chunk{}, errors.New("invalid transfer id")
	}
	index, err := readUint32(reader)
	if err != nil {
		return Chunk{}, err
	}
	total, err := readUint32(reader)
	if err != nil || total == 0 || total > MaxChunks || index >= total {
		return Chunk{}, errors.New("invalid transfer metadata")
	}
	salt, err := readSized()
	if err != nil {
		return Chunk{}, err
	}
	nonce, err := readSized()
	if err != nil {
		return Chunk{}, err
	}
	cipherLength, err := readUint32(reader)
	if err != nil || uint64(cipherLength) > uint64(reader.Len()) {
		return Chunk{}, errors.New("truncated transfer chunk")
	}
	cipherText := make([]byte, cipherLength)
	if _, err := io.ReadFull(reader, cipherText); err != nil {
		return Chunk{}, errors.New("truncated transfer chunk")
	}
	mac, err := readSized()
	if err != nil || reader.Len() != 0 {
		return Chunk{}, errors.New("invalid transfer metadata")
	}
	return Chunk{TransferID: string(idBytes), ProtocolVersion: version, Index: index, Total: total, Salt: salt, Nonce: nonce, CipherText: cipherText, MAC: mac, Encrypted: flag == 1}, nil
}

func writeUint32(writer io.Writer, value uint32) {
	var word [4]byte
	binary.BigEndian.PutUint32(word[:], value)
	_, _ = writer.Write(word[:])
}

func readUint32(reader io.Reader) (uint32, error) {
	var word [4]byte
	if _, err := io.ReadFull(reader, word[:]); err != nil {
		return 0, errors.New("truncated transfer chunk")
	}
	return binary.BigEndian.Uint32(word[:]), nil
}
