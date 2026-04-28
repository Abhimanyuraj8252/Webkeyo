import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 1024, height: 1024);
  
  // Very simple dark premium background
  img.fill(image, color: img.ColorRgb8(15, 23, 42)); // Dark Slate
  
  // W shaped polygon
  img.drawLine(image, x1: 220, y1: 300, x2: 350, y2: 750, color: img.ColorRgb8(56, 189, 248), thickness: 70); 
  img.drawLine(image, x1: 350, y1: 750, x2: 512, y2: 500, color: img.ColorRgb8(56, 189, 248), thickness: 70); 
  img.drawLine(image, x1: 512, y1: 500, x2: 674, y2: 750, color: img.ColorRgb8(129, 140, 248), thickness: 70); 
  img.drawLine(image, x1: 674, y1: 750, x2: 804, y2: 300, color: img.ColorRgb8(129, 140, 248), thickness: 70); 
  
  File('assets/logo.png').writeAsBytesSync(img.encodePng(image));
  // ignore: avoid_print
  print('Logo generated');
}
