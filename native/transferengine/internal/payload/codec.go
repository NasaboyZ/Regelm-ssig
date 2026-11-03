package payload

import (
	"crypto/subtle"
	"errors"
	"fmt"

	transfercrypto "regelmaessig/native/transferengine/internal/crypto"
	"regelmaessig/native/transferengine/internal/protocol"
)

const MaxChunkSize = 1800

func Encode(input []byte, transferID, passphrase string, chunkSize int, encrypted bool) ([]protocol.Chunk, error) {
	if len(transferID) == 0 || len(transferID) > protocol.MaxTransferID || chunkSize < 1 || chunkSize > MaxChunkSize || (encrypted && passphrase == "") {
		return nil, errors.New("invalid transfer input")
	}
	compressed, err := transfercrypto.Compress(input)
	if err != nil {
		return nil, err
	}
	var salt, nonce, mac, ciphertext []byte
	if encrypted {
		ciphertext, salt, nonce, mac, err = transfercrypto.Encrypt(compressed, passphrase, transferID)
		if err != nil {
			return nil, err
		}
	} else {
		ciphertext = compressed
	}
	count := (len(ciphertext) + chunkSize - 1) / chunkSize
	if count == 0 {
		count = 1
	}
	if count > protocol.MaxChunks {
		return nil, errors.New("transfer has too many chunks")
	}
	chunks := make([]protocol.Chunk, count)
	for index := range chunks {
		start := index * chunkSize
		end := start + chunkSize
		if end > len(ciphertext) {
			end = len(ciphertext)
		}
		chunks[index] = protocol.Chunk{
			TransferID: transferID, ProtocolVersion: protocol.ProtocolVersion,
			Index: uint32(index), Total: uint32(count), Salt: clone(salt),
			Nonce: clone(nonce), CipherText: clone(ciphertext[start:end]),
			MAC: clone(mac), Encrypted: encrypted,
		}
	}
	return chunks, nil
}

func Decode(chunks []protocol.Chunk, passphrase string) ([]byte, error) {
	if len(chunks) == 0 {
		return nil, errors.New("empty transfer")
	}
	first := chunks[0]
	if first.ProtocolVersion != protocol.ProtocolVersion || uint32(len(chunks)) != first.Total || first.Total == 0 || first.Total > protocol.MaxChunks {
		return nil, errors.New("incomplete or incompatible transfer")
	}
	ordered := make([]protocol.Chunk, first.Total)
	seen := make([]bool, first.Total)
	for _, chunk := range chunks {
		if chunk.TransferID != first.TransferID || chunk.ProtocolVersion != first.ProtocolVersion || chunk.Total != first.Total || chunk.Encrypted != first.Encrypted || chunk.Index >= chunk.Total || !equal(chunk.Salt, first.Salt) || !equal(chunk.Nonce, first.Nonce) || !equal(chunk.MAC, first.MAC) {
			return nil, errors.New("inconsistent transfer chunks")
		}
		if seen[chunk.Index] {
			return nil, errors.New("duplicate transfer index")
		}
		ordered[chunk.Index] = chunk
		seen[chunk.Index] = true
	}
	var ciphertext []byte
	for index, chunk := range ordered {
		if !seen[index] {
			return nil, fmt.Errorf("missing transfer chunk %d", index)
		}
		ciphertext = append(ciphertext, chunk.CipherText...)
	}
	clear := ciphertext
	if first.Encrypted {
		var err error
		clear, err = transfercrypto.Decrypt(ciphertext, first.Salt, first.Nonce, first.MAC, passphrase, first.TransferID)
		if err != nil {
			return nil, err
		}
	}
	return transfercrypto.Decompress(clear)
}

func clone(input []byte) []byte {
	return append([]byte(nil), input...)
}

func equal(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	return subtle.ConstantTimeCompare(a, b) == 1
}
