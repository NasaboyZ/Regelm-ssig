package mlqr

import (
	"errors"

	qrcode "github.com/skip2/go-qrcode"
)

const MaxLayers = 15

type RenderOptions struct {
	MaxLayersPerCode int
	PadWithDummies   bool
}

type Raster struct {
	Width      int
	Height     int
	PixelsRGB  []byte
	QRVersion  int
	Payloads   int
	LayerCount int
}

func RenderPackets(packets [][]byte, options RenderOptions) ([]Raster, error) {
	if len(packets) == 0 || len(packets) > MaxLayers {
		return nil, errors.New("expected between one and fifteen packets")
	}
	if options.MaxLayersPerCode < 1 || options.MaxLayersPerCode > MaxLayers {
		return nil, errors.New("invalid maximum layer count")
	}
	frames := make([]Raster, 0, (len(packets)+options.MaxLayersPerCode-1)/options.MaxLayersPerCode)
	for start := 0; start < len(packets); start += options.MaxLayersPerCode {
		end := start + options.MaxLayersPerCode
		if end > len(packets) {
			end = len(packets)
		}
		frame, err := renderGroup(packets[start:end], options.PadWithDummies)
		if err != nil {
			return nil, err
		}
		frames = append(frames, frame)
	}
	return frames, nil
}

func renderGroup(packets [][]byte, pad bool) (Raster, error) {
	version := 1
	mats := make([][][]bool, len(packets))
	for _, packet := range packets {
		code, err := qrcode.New(string(packet), qrcode.Medium)
		if err != nil {
			return Raster{}, err
		}
		if code.VersionNumber > version {
			version = code.VersionNumber
		}
	}
	for index, packet := range packets {
		code, err := qrcode.NewWithForcedVersion(string(packet), version, qrcode.Medium)
		if err != nil {
			return Raster{}, err
		}
		bitmap := code.Bitmap()
		if len(bitmap) < 9 {
			return Raster{}, errors.New("invalid QR bitmap")
		}
		core := make([][]bool, len(bitmap)-8)
		for row := range core {
			core[row] = append([]bool(nil), bitmap[row+4][4:len(bitmap)-4]...)
		}
		mats[index] = core
	}
	return compose(mats, version, pad)
}

func compose(mats [][][]bool, version int, pad bool) (Raster, error) {
	if len(mats) == 0 {
		return Raster{}, errors.New("empty matrix group")
	}
	size := len(mats[0])
	partition := partitionFor(len(mats))
	total := len(mats)
	if pad {
		total = len(partition) * 3
	}
	if total > len(mats) && size < 21 {
		return Raster{}, errors.New("dummy layers require a QR-sized matrix")
	}
	pixels := make([]byte, size*size*3)
	for index := range pixels {
		pixels[index] = 0
	}
	for layer := 0; layer < total; layer++ {
		matrix := dummy(size)
		if layer < len(mats) {
			matrix = mats[layer]
		}
		channel := layer / len(partition)
		weight := partition[layer%len(partition)]
		for pixel := 0; pixel < size*size; pixel++ {
			if !matrix[pixel/size][pixel%size] {
				value := int(pixels[pixel*3+channel]) + weight
				if value > 255 {
					value = 255
				}
				pixels[pixel*3+channel] = byte(value)
			}
		}
	}
	return decorate(Raster{Width: size, Height: size, PixelsRGB: pixels, QRVersion: version, Payloads: len(mats), LayerCount: total}), nil
}

func decorate(core Raster) Raster {
	width := core.Width + 5 + 4
	height := core.Height + 4 + 4
	pixels := make([]byte, width*height*3)
	for index := range pixels {
		pixels[index] = 255
	}
	for row := 0; row < core.Height; row++ {
		for col := 0; col < core.Width; col++ {
			source := (row*core.Width + col) * 3
			destination := ((row+4)*width + col + 5) * 3
			copy(pixels[destination:destination+3], core.PixelsRGB[source:source+3])
		}
	}
	reference := [][3]byte{{0, 255, 0}, {0, 0, 255}, {255, 0, 0}}
	for layer := 0; layer < core.LayerCount; layer++ {
		color := reference[layer%len(reference)]
		index := ((layer + 4) * width) * 3
		copy(pixels[index:index+3], color[:])
	}
	core.Width = width
	core.Height = height
	core.PixelsRGB = pixels
	return core
}

func partitionFor(layerCount int) []int {
	length := (layerCount + 2) / 3
	step := 255 / ((1 << length) - 1)
	weights := make([]int, length)
	for index := 0; index < length-1; index++ {
		weights[index] = step * (1 << index)
	}
	sum := 0
	for _, weight := range weights {
		sum += weight
	}
	weights[length-1] = 255 - sum
	return weights
}

func dummy(size int) [][]bool {
	result := make([][]bool, size)
	for row := range result {
		result[row] = make([]bool, size)
	}
	for _, position := range [][2]int{{0, 0}, {0, size - 7}, {size - 7, 0}} {
		for row := 0; row < 7; row++ {
			for col := 0; col < 7; col++ {
				result[position[0]+row][position[1]+col] = row == 0 || row == 6 || col == 0 || col == 6 || (row >= 2 && row <= 4 && col >= 2 && col <= 4)
			}
		}
	}
	return result
}
