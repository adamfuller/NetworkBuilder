library neural_network;

import 'dart:math';

part 'layer.dart';
part 'neuron.dart';

class Network {
  static ActivationFunction activationFunction;
  List<Layer> layers;
  List<int> hiddenLayerNeuronCount;
  int timesRun = 0;
  double averagePercentError = 0;
  List<double> pastErrors = List<double>();

  int get maxLayerSize {
    int max = 0;
    for (Layer l in layers) {
      if (l.neurons.length > max) {
        max = l.neurons.length;
      }
    }
    return max;
  }

  Network(this.hiddenLayerNeuronCount, {ActivationFunction normalizationFunction}) {
    Network.activationFunction ??= ActivationFunction.sigmoid;
    this.layers ??= List<Layer>();
    // Add a layer for each count
    for (int i = 0; i < hiddenLayerNeuronCount.length - 1; i++) {
      layers.add(
        Layer(
          hiddenLayerNeuronCount[i],
          hiddenLayerNeuronCount[i + 1],
          normalizationFunction: normalizationFunction,
        ),
      );
    }
  }

  List<double> feedForward(List<double> inputs) {
    layers[0].forwardPropagation(inputs);

    for (int i = 1; i < this.layers.length; i++) {
      layers[i].forwardPropagation(layers[i - 1].outputs);
    }

    return layers.last.outputs;
  }

  void backPropagation(List<double> expected) {
    timesRun++;
    double expectedSum = 0;
    for (double v in expected) expectedSum += v;
    double calculatedSum = 0;
    for (double v in this.layers.last.outputs) calculatedSum += v;
    double currentError = expectedSum > 0 ? (expectedSum - calculatedSum) / expectedSum * 100 : 0;
    pastErrors.add(currentError);
    this.averagePercentError = 0;
    for (int i = 0; i < pastErrors.length; i++) {
      averagePercentError += pastErrors[i];
    }
    averagePercentError /= pastErrors.length;
    if (pastErrors.length > 5 && currentError > 0) {
      pastErrors.removeAt(0);
    }
    //
    // End of error calculation
    //

    // Calculate output layer
    layers[layers.length - 1].backPropagationOutput(expected);

    // calculate input layers
    for (int i = this.layers.length - 2; i >= 0; i--) {
      layers[i].backPropagationHidden(layers[i + 1].gamma, layers[i + 1].weightsByNeuron);
    }

    // Update all the weights
    this.layers.forEach((l) => l.updateWeights());
  }
}
