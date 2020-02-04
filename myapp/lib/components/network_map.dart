import 'package:custom_widget/custom_widget.dart';
import 'package:flutter/material.dart';
import 'package:network_builder/network/network.dart';

class NetworkMap extends StatelessWidget {
  static int count = 0;
  static final Paint neuronPaint = Paint()..color = Color.fromARGB(235, 0x21, 0x96, 0xF3);
  final Network network;
  static const double diameter = 10;
  static const double spaceAround = 20;

  NetworkMap({
    @required this.network,
  });

  @override
  Widget build(BuildContext context) {
    return CustomWidget(
      size: MediaQuery.of(context).size.shortestSide * 3 / 4,
      doesRepaint: false,
      onPaint: (c, s, d) {
        Paint linePaint = Paint();
        linePaint.strokeWidth = 1.5;

        double spaceBetweenLayers = s.width / (network.layers.length + 1);
        
        List<List<Offset>> positions = List<List<Offset>>();
        List<Rect> nodePositions = List<Rect>();

        for (int i = 0; i < network.layers.length + 1; i++) {
          positions.add(List<Offset>());
          List<Layer> sub = network.layers.take(i).toList();
          Layer layer = (sub.length > 0 && i < network.layers.length) ? sub.last : null;
          int nodeCount = layer != null ? layer.neurons.length : network.layers[0].neurons[0].weights.length;
          if (i == network.layers.length) {
            nodeCount = network.layers.last.neurons.length;
          }
          double spaceBetweenNodes = (s.height - 2 * spaceAround) / nodeCount;
          double layerXPosition = spaceBetweenLayers / 2 + i * spaceBetweenLayers;
          // Draw the nodes
          for (int j = 0; j < nodeCount; j++) {
            double nodeYPosition = spaceBetweenNodes / 2 + spaceBetweenNodes * j + spaceAround;
            Rect nodeRect = Rect.fromLTWH(layerXPosition, nodeYPosition, diameter, diameter);
            nodePositions.add(nodeRect);
            // Add points
            positions[i].add(Offset(layerXPosition + diameter / 2, nodeYPosition + diameter / 2));
          }
        }

        for (int i = 1; i < positions.length; i++) {
          // Draw from all in i to i-1
          // i-i is the index in the layers
          // j is the index of the weight
          for (int j = 0; j < positions[i].length; j++) {
            // position of point on right
            // index of the neuron
            for (int x = 0; x < positions[i - 1].length; x++) {
              // position of point to the left
              // also index of the weight
              double weight = network.layers[i - 1].neurons[j].weights[x];
              if (weight <= 1) weight *= 255;
              else weight = (weight.sign*255);
              int red = (weight > 0 ? weight : 0).floor();
              int green = (weight < 0 ? weight : 0).floor();
              linePaint.color = Color.fromARGB(255, red, green, 0);
              c.drawLine(positions[i][j], positions[i - 1][x], linePaint);
            }
          }
        }

        for (Rect r in nodePositions) {
          c.drawArc(r, 0, 6.29, true, neuronPaint);
        }
      },
    );
  }
}