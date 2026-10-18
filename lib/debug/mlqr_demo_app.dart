import 'package:flutter/material.dart';

import '../models/mlqr_code.dart';
import '../services/mlqr_encoder_service.dart';
import '../viewmodels/mlqr_demo_view_model.dart';
import '../widgets/transfer/mlqr_raster_view.dart';

class MlqrDemoApp extends StatelessWidget {
  const MlqrDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MLQR Encoder-Test',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff456c70)),
      scaffoldBackgroundColor: const Color(0xfff7f5f1),
    ),
    home: const _DemoScreen(),
  );
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  final _model = MlqrDemoViewModel();

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MLQR · Encoder-Test')),
    body: ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final code = _model.code;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Testdaten · kein Gesundheitsdaten-Transfer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Encoder nach Noppakaew, Khomkuth & Sriwilas (2018). '
                    'Der Kamera-Decoder folgt in einem separaten Schritt.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    initialValue: _model.layerCount,
                    decoration: const InputDecoration(
                      labelText: 'Nutzdatenebenen',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (
                        var i = 1;
                        i <= MlqrEncoderService.maxPayloadLayers;
                        i++
                      )
                        DropdownMenuItem(value: i, child: Text('$i Ebenen')),
                    ],
                    onChanged: (value) => _model.configure(layerCount: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mit Dummy-Ebenen ergänzen'),
                    subtitle: const Text(
                      'Ergänzt auf das nächste Vielfache von 3.',
                    ),
                    value: _model.padWithDummies,
                    onChanged: (value) =>
                        _model.configure(padWithDummies: value),
                  ),
                  if (_model.error != null) Text(_model.error!),
                  if (code != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: MlqrRasterView(raster: code.displayRaster),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${code.payloadCount} Nutzdaten + ${code.dummyCount} Dummys'
                      ' = ${code.layers.length} dargestellte Ebenen',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Partition: ${code.partition.join(', ')}'),
                    Text(
                      'QR-Version ${code.qrVersion} · '
                      '${code.raster.width} × ${code.raster.height} Module · '
                      'Fehlerkorrektur M',
                    ),
                    const Text(
                      'Referenzbalken: ein Kästchen pro dargestellter Ebene.',
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Ursprüngliche Ebenen',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < code.layers.length; i++)
                          _LayerPreview(
                            layer: code.layers[i],
                            number: i + 1,
                            text: code.layers[i].isDummy
                                ? 'Keine Nutzdaten'
                                : _model.sampleTexts[code
                                      .layers[i]
                                      .payloadIndex!],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _LayerPreview extends StatelessWidget {
  const _LayerPreview({
    required this.layer,
    required this.number,
    required this.text,
  });

  final MlqrLayer layer;
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final matrix = layer.matrix;
    final side = matrix.size + 8;
    final raster = MlqrRgbRaster(
      width: side,
      height: side,
      pixels: [
        for (var row = 0; row < side; row++)
          for (var col = 0; col < side; col++)
            row >= 4 &&
                    row < side - 4 &&
                    col >= 4 &&
                    col < side - 4 &&
                    matrix.isDark(row - 4, col - 4)
                ? 0x000000
                : 0xffffff,
      ],
    );
    final channel = ['Rot', 'Grün', 'Blau'][layer.channel.index];
    return SizedBox(
      width: 210,
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlqrRasterView(raster: raster, maxExtent: 180),
              const SizedBox(height: 8),
              Text('Ebene $number${layer.isDummy ? ' · Dummy' : ''}'),
              Text('$channel · Gewicht ${layer.weight}'),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
