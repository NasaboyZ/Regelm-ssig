package crypto

import (
	"bytes"
	"compress/gzip"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"errors"
	"fmt"
	"io"

	"crypto/sha256"
	"golang.org/x/crypto/pbkdf2"
)

const (
	SaltLength       = 16
	PBKDF2Iterations = 10000
	KeyLength        = 32
	MaxInflatedSize  = 16 << 20
)

func Compress(input []byte) ([]byte, error) {
	var output bytes.Buffer
	writer := gzip.NewWriter(&output)
	if _, err := writer.Write(input); err != nil {
		return nil, fmt.Errorf("compress payload: %w", err)
	}
	if err := writer.Close(); err != nil {
		return nil, fmt.Errorf("close compressed payload: %w", err)
	}
	return output.Bytes(), nil
}

func Decompress(input []byte) ([]byte, error) {
	reader, err := gzip.NewReader(bytes.NewReader(input))
	if err != nil {
		return nil, fmt.Errorf("open compressed payload: %w", err)
	}
	defer reader.Close()
	limited := io.LimitReader(reader, MaxInflatedSize+1)
	output, err := io.ReadAll(limited)
	if err != nil {
		return nil, fmt.Errorf("read compressed payload: %w", err)
	}
	if len(output) > MaxInflatedSize {
		return nil, errors.New("decompressed payload exceeds limit")
	}
	return output, nil
}

func Encrypt(compressed []byte, passphrase, transferID string) (ciphertext, salt, nonce, mac []byte, err error) {
	salt = make([]byte, SaltLength)
	if _, err = rand.Read(salt); err != nil {
		return nil, nil, nil, nil, fmt.Errorf("create salt: %w", err)
	}
	key := pbkdf2.Key([]byte(passphrase), salt, PBKDF2Iterations, KeyLength, sha256.New)
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, nil, nil, nil, fmt.Errorf("create cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, nil, nil, nil, fmt.Errorf("create authenticated cipher: %w", err)
	}
	nonce = make([]byte, gcm.NonceSize())
	if _, err = rand.Read(nonce); err != nil {
		return nil, nil, nil, nil, fmt.Errorf("create nonce: %w", err)
	}
	sealed := gcm.Seal(nil, nonce, compressed, []byte(fmt.Sprintf("regelmaessig.transfer:1:%s", transferID)))
	mac = append([]byte(nil), sealed[len(sealed)-gcm.Overhead():]...)
	return sealed[:len(sealed)-gcm.Overhead()], salt, nonce, mac, nil
}

func Decrypt(ciphertext, salt, nonce, mac []byte, passphrase, transferID string) ([]byte, error) {
	key := pbkdf2.Key([]byte(passphrase), salt, PBKDF2Iterations, KeyLength, sha256.New)
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("create cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("create authenticated cipher: %w", err)
	}
	sealed := append(append([]byte(nil), ciphertext...), mac...)
	clear, err := gcm.Open(nil, nonce, sealed, []byte(fmt.Sprintf("regelmaessig.transfer:1:%s", transferID)))
	if err != nil {
		return nil, errors.New("transfer authentication failed")
	}
	return clear, nil
}
