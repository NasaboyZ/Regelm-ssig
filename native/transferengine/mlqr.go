package transferengine

import (
	"time"

	"regelmaessig/native/transferengine/internal/mlqr"
)

const MaxLayers = mlqr.MaxLayers

type RenderOptions = mlqr.RenderOptions
type Raster = mlqr.Raster

func RenderPackets(packets [][]byte, options RenderOptions) ([]Raster, error) {
	return defaultEngine.RenderPackets(packets, options)
}

func (e *Engine) RenderPackets(packets [][]byte, options RenderOptions) ([]Raster, error) {
	started := time.Now()
	frames, err := mlqr.RenderPackets(packets, options)
	e.logger.Info("mlqr.render", "duration_ms", time.Since(started).Milliseconds(), "packets", len(packets), "sequences", len(frames), "max_layers", options.MaxLayersPerCode, "success", err == nil)
	return frames, err
}
