import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ColorPickerApp());
}

class ColorPickerApp extends StatelessWidget {
  const ColorPickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Picker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const ColorPickerPage(),
    );
  }
}

class ColorPickerPage extends StatefulWidget {
  const ColorPickerPage({super.key});

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  int _currentIndex = 0;
  double _hue = 0;
  double _saturation = 1.0;
  double _value = 1.0;
  List<int> _savedColors = [];

  Color get _currentColor => hsvToColor(_hue, _saturation, _value);

  @override
  void initState() {
    super.initState();
    _loadSavedColors();
  }

  Future<void> _loadSavedColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('saved_colors') ?? [];
      _savedColors = saved.map((s) => int.parse(s)).toList();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'saved_colors',
        _savedColors.map((c) => c.toString()).toList(),
      );
    } catch (_) {}
  }

  void _onColorChanged(double h, double s, double v) {
    setState(() {
      _hue = h;
      _saturation = s;
      _value = v;
    });
  }

  void _addToSavedColors() {
    final colorValue = _currentColor.toARGB32();
    if (!_savedColors.contains(colorValue)) {
      setState(() {
        _savedColors.insert(0, colorValue);
        if (_savedColors.length > 50) {
          _savedColors = _savedColors.sublist(0, 50);
        }
      });
      _saveColors();
    }
  }

  void _selectSavedColor(Color color) {
    final hsv = colorToHsv(color);
    setState(() {
      _hue = hsv[0];
      _saturation = hsv[1];
      _value = hsv[2];
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Picker'),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PickerTab(
            hue: _hue,
            saturation: _saturation,
            value: _value,
            onColorChanged: _onColorChanged,
            onSave: _addToSavedColors,
          ),
          PaletteTab(color: _currentColor),
          SavedColorsTab(
            colors: _savedColors,
            onSelect: _selectSavedColor,
            onDelete: (index) {
              setState(() {
                _savedColors.removeAt(index);
              });
              _saveColors();
            },
          ),
          PhotoPickerTab(onColorPicked: _selectSavedColor),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.colorize),
            label: 'Picker',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette),
            label: 'Palette',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo),
            label: 'Photo',
          ),
        ],
      ),
    );
  }
}

class PickerTab extends StatelessWidget {
  final double hue;
  final double saturation;
  final double value;
  final void Function(double h, double s, double v) onColorChanged;
  final VoidCallback onSave;

  const PickerTab({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onColorChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final color = hsvToColor(hue, saturation, value);
    final rgb = colorToRgb(color);
    final isDark = color.computeLuminance() < 0.5;
    final textColor = isDark ? Colors.white70 : Colors.black54;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ColorPreviewCard(
            color: color,
            textColor: textColor,
            rgb: rgb,
            onSave: onSave,
          ),
          const SizedBox(height: 20),
          _HsvWheel(
            hue: hue,
            saturation: saturation,
            value: value,
            onChanged: onColorChanged,
          ),
          const SizedBox(height: 16),
          _ValueSlider(
            value: value,
            hue: hue,
            saturation: saturation,
            onChanged: (v) => onColorChanged(hue, saturation, v),
          ),
          const SizedBox(height: 16),
          _RgbSliders(
            rgb: rgb,
            onChanged: (r, g, b) {
              final hsv = rgbToHsv(r, g, b);
              onColorChanged(hsv[0], hsv[1], hsv[2]);
            },
          ),
        ],
      ),
    );
  }
}

class _ColorPreviewCard extends StatelessWidget {
  final Color color;
  final Color textColor;
  final List<int> rgb;
  final VoidCallback onSave;

  const _ColorPreviewCard({
    required this.color,
    required this.textColor,
    required this.rgb,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hex = colorToHex(color);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 80,
            color: color,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CodeRow(
                        label: 'HEX',
                        value: hex,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 4),
                      _CodeRow(
                        label: 'RGB',
                        value: '(${rgb[0]}, ${rgb[1]}, ${rgb[2]})',
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add),
                  tooltip: 'Save',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;

  const _CodeRow({
    required this.label,
    required this.value,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          iconSize: 18,
          icon: const Icon(Icons.copy),
          tooltip: 'Copy $label',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: label == 'HEX' ? value : value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HsvWheel extends StatefulWidget {
  final double hue;
  final double saturation;
  final double value;
  final void Function(double h, double s, double v) onChanged;

  const _HsvWheel({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_HsvWheel> createState() => _HsvWheelState();
}

class _HsvWheelState extends State<_HsvWheel> {
  void _handlePan(DragUpdateDetails details) {
    _updateFromPosition(details.localPosition);
  }

  void _handleTap(TapUpDetails details) {
    _updateFromPosition(details.localPosition);
  }

  void _updateFromPosition(Offset pos) {
    final size = context.size;
    if (size == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final hue = ((math.atan2(dy, dx) * 180 / math.pi) + 360) % 360;
    final saturation = (distance / radius).clamp(0.0, 1.0);

    widget.onChanged(hue, saturation, widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _handlePan,
      onTapUp: _handleTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _HsvWheelPainter(
            hue: widget.hue,
            saturation: widget.saturation,
            value: widget.value,
          ),
        ),
      ),
    );
  }
}

class _HsvWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _HsvWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(0),
    ));

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    final hueColors = <Color>[
      const Color(0xFFFF0000),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF00FFFF),
      const Color(0xFF0000FF),
      const Color(0xFFFF00FF),
      const Color(0xFFFF0000),
    ];
    final sweepShader = SweepGradient(
      colors: hueColors,
      transform: _GradientRotation(-math.pi / 2),
    ).createShader(rect);

    canvas.drawCircle(center, radius, Paint()..shader = sweepShader);

    final satShader = RadialGradient(
      colors: [Colors.white, Colors.transparent],
      stops: const [0.0, 1.0],
    ).createShader(rect);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = satShader
        ..blendMode = BlendMode.srcATop,
    );

    final valOpacity = 1.0 - value;
    if (valOpacity > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: valOpacity),
      );
    }

    final indicatorAngle = (hue * math.pi / 180) - math.pi / 2;
    final indicatorDistance = saturation * radius;
    final indicatorPos = Offset(
      center.dx + math.cos(indicatorAngle) * indicatorDistance,
      center.dy + math.sin(indicatorAngle) * indicatorDistance,
    );

    canvas.drawCircle(
      indicatorPos,
      10,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      indicatorPos,
      10,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _HsvWheelPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}

class _GradientRotation extends GradientTransform {
  final double angle;

  const _GradientRotation(this.angle);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()
      ..translateByDouble(bounds.center.dx, bounds.center.dy, 0, 1)
      ..rotateZ(angle)
      ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
  }
}

class _ValueSlider extends StatelessWidget {
  final double value;
  final double hue;
  final double saturation;
  final ValueChanged<double> onChanged;

  const _ValueSlider({
    required this.value,
    required this.hue,
    required this.saturation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brightness', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 24,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RgbSliders extends StatelessWidget {
  final List<int> rgb;
  final void Function(int r, int g, int b) onChanged;

  const _RgbSliders({
    required this.rgb,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RGB Fine-Tune', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        _RgbSlider(
          label: 'R',
          color: Colors.red,
          value: rgb[0],
          onChanged: (v) => onChanged(v, rgb[1], rgb[2]),
        ),
        _RgbSlider(
          label: 'G',
          color: Colors.green,
          value: rgb[1],
          onChanged: (v) => onChanged(rgb[0], v, rgb[2]),
        ),
        _RgbSlider(
          label: 'B',
          color: Colors.blue,
          value: rgb[2],
          onChanged: (v) => onChanged(rgb[0], rgb[1], v),
        ),
      ],
    );
  }
}

class _RgbSlider extends StatelessWidget {
  final String label;
  final Color color;
  final int value;
  final ValueChanged<int> onChanged;

  const _RgbSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              trackHeight: 6,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ),
      ],
    );
  }
}

class PaletteTab extends StatelessWidget {
  final Color color;

  const PaletteTab({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final hsv = colorToHsv(color);
    final h = hsv[0];
    final s = hsv[1];
    final v = hsv[2];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ColorHeader(color: color),
          const SizedBox(height: 20),
          _PaletteSection(
            title: 'Complementary',
            colors: [
              hsvToColor(h, s, v),
              hsvToColor((h + 180) % 360, s, v),
            ],
          ),
          const SizedBox(height: 16),
          _PaletteSection(
            title: 'Analogous',
            colors: [
              hsvToColor((h - 30 + 360) % 360, s, v),
              hsvToColor(h, s, v),
              hsvToColor((h + 30) % 360, s, v),
            ],
          ),
          const SizedBox(height: 16),
          _PaletteSection(
            title: 'Triadic',
            colors: [
              hsvToColor(h, s, v),
              hsvToColor((h + 120) % 360, s, v),
              hsvToColor((h + 240) % 360, s, v),
            ],
          ),
          const SizedBox(height: 16),
          _PaletteSection(
            title: 'Tetradic',
            colors: [
              hsvToColor(h, s, v),
              hsvToColor((h + 60) % 360, s, v),
              hsvToColor((h + 180) % 360, s, v),
              hsvToColor((h + 240) % 360, s, v),
            ],
          ),
          const SizedBox(height: 16),
          _PaletteSection(
            title: 'Monochrome',
            colors: [
              hsvToColor(h, s, 1.0),
              hsvToColor(h, s, 0.8),
              hsvToColor(h, s, 0.6),
              hsvToColor(h, s, 0.4),
              hsvToColor(h, s, 0.2),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorHeader extends StatelessWidget {
  final Color color;

  const _ColorHeader({required this.color});

  @override
  Widget build(BuildContext context) {
    final rgb = colorToRgb(color);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              colorToHex(color),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            Text(
              'RGB(${rgb[0]}, ${rgb[1]}, ${rgb[2]})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _PaletteSection extends StatelessWidget {
  final String title;
  final List<Color> colors;

  const _PaletteSection({
    required this.title,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: Row(
                children: colors.map((c) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final hex = colorToHex(c);
                        Clipboard.setData(ClipboardData(text: hex));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$hex copied'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(7),
                            ),
                            color: Colors.black38,
                          ),
                          child: Text(
                            colorToHex(c),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedColorsTab extends StatelessWidget {
  final List<int> colors;
  final void Function(Color color) onSelect;
  final void Function(int index) onDelete;

  const SavedColorsTab({
    super.key,
    required this.colors,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'No saved colors',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final color = Color(colors[index]);
        return GestureDetector(
          onTap: () => onSelect(color),
          onLongPress: () => _showDeleteDialog(context, index, color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, int index, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Color'),
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Text(colorToHex(color)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onDelete(index);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class PhotoPickerTab extends StatefulWidget {
  final void Function(Color color) onColorPicked;

  const PhotoPickerTab({super.key, required this.onColorPicked});

  @override
  State<PhotoPickerTab> createState() => _PhotoPickerTabState();
}

class _PhotoPickerTabState extends State<PhotoPickerTab> {
  final _imagePicker = ImagePicker();
  final _containerKey = GlobalKey();
  String? _imagePath;
  ui.Image? _decodedImage;
  Color? _pickedColor;

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _imagePath = picked.path;
      _decodedImage = frame.image;
      _pickedColor = null;
    });
  }

  void _onImageTap(TapUpDetails details) {
    if (_decodedImage == null) return;
    final renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final containerSize = renderBox.size;
    final localPos = details.localPosition;

    final imageWidth = _decodedImage!.width.toDouble();
    final imageHeight = _decodedImage!.height.toDouble();

    final scale = math.min(
      containerSize.width / imageWidth,
      containerSize.height / imageHeight,
    );
    final displayWidth = imageWidth * scale;
    final displayHeight = imageHeight * scale;
    final offsetX = (containerSize.width - displayWidth) / 2;
    final offsetY = (containerSize.height - displayHeight) / 2;

    if (localPos.dx < offsetX ||
        localPos.dx > offsetX + displayWidth ||
        localPos.dy < offsetY ||
        localPos.dy > offsetY + displayHeight) {
      return;
    }

    final imageX =
        ((localPos.dx - offsetX) / scale).round().clamp(0, _decodedImage!.width - 1);
    final imageY =
        ((localPos.dy - offsetY) / scale).round().clamp(0, _decodedImage!.height - 1);

    _readPixel(imageX, imageY);
  }

  Future<void> _readPixel(int x, int y) async {
    final byteData =
        await _decodedImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final offset = (y * _decodedImage!.width + x) * 4;
    final r = byteData.getUint8(offset);
    final g = byteData.getUint8(offset + 1);
    final b = byteData.getUint8(offset + 2);
    final color = Color.fromARGB(255, r, g, b);

    setState(() {
      _pickedColor = color;
    });
    widget.onColorPicked(color);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _imagePath == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        'Pick a photo to extract colors',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white38,
                            ),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTapUp: _onImageTap,
                  child: Container(
                    key: _containerKey,
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (_pickedColor != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _pickedColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick Photo'),
                ),
              ),
              if (_pickedColor != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _pickedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

Color hsvToColor(double h, double s, double v) {
  final c = v * s;
  final hh = h / 60;
  final x = c * (1 - ((hh % 2) - 1).abs());
  final m = v - c;

  double r, g, b;
  if (hh < 1) {
    r = c;
    g = x;
    b = 0;
  } else if (hh < 2) {
    r = x;
    g = c;
    b = 0;
  } else if (hh < 3) {
    r = 0;
    g = c;
    b = x;
  } else if (hh < 4) {
    r = 0;
    g = x;
    b = c;
  } else if (hh < 5) {
    r = x;
    g = 0;
    b = c;
  } else {
    r = c;
    g = 0;
    b = x;
  }

  return Color.fromARGB(
    255,
    ((r + m) * 255).round().clamp(0, 255),
    ((g + m) * 255).round().clamp(0, 255),
    ((b + m) * 255).round().clamp(0, 255),
  );
}

List<double> colorToHsv(Color color) {
  final r = ((color.r * 255).round().clamp(0, 255)) / 255;
  final g = ((color.g * 255).round().clamp(0, 255)) / 255;
  final b = ((color.b * 255).round().clamp(0, 255)) / 255;

  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  final delta = max - min;

  double h = 0;
  if (delta != 0) {
    if (max == r) {
      h = ((g - b) / delta) % 6;
    } else if (max == g) {
      h = ((b - r) / delta) + 2;
    } else {
      h = ((r - g) / delta) + 4;
    }
    h *= 60;
    if (h < 0) h += 360;
  }

  final s = max == 0 ? 0.0 : delta / max;
  final v = max;

  return [h, s, v];
}

List<double> rgbToHsv(int r, int g, int b) {
  return colorToHsv(Color.fromARGB(255, r, g, b));
}

List<int> colorToRgb(Color color) {
  return [(color.r * 255).round().clamp(0, 255), (color.g * 255).round().clamp(0, 255), (color.b * 255).round().clamp(0, 255)];
}

String colorToHex(Color color) {
  final r = (color.r * 255).round().clamp(0, 255);
  final g = (color.g * 255).round().clamp(0, 255);
  final b = (color.b * 255).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}
