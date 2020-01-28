part of "network.dart";

class Layer {
  static Random r = Random();
  static double learningRate = 0.033;

  List<Neuron> neurons;
  ActivationFunction normalizationFunction;

  /// Weights per neuron
  // int inputCount;

  /// Number or neurons
  // int outputCount;

  List<List<double>> get weights => this.neurons.map<List<double>>((n) => n.weights).toList();
  /// Flip the weights so they are weights[weightIndex][neuronIndex]
  List<List<double>> get weightsByNeuron {
    List<List<double>> ws = List<List<double>>();
    List<List<double>> normalWeights = this.weights;
    for (int i = 0; i < this.neurons[0].weights.length; i++) {
      ws.add(List<double>());
    }
    // Flip the weights so they are weights[weightIndex][neuronIndex]
    for (int i = 0; i < this.neurons.length; i++) {
      for (int j = 0; j < this.neurons[0].weights.length; j++) {
        ws[j].add(normalWeights[i][j]);
      }
    }

    return ws;
  }

  List<double> get gamma => this.neurons.map<double>((n) => n.gamma).toList();
  List<double> get outputs => this.neurons.map<double>((n) => n.output).toList();

  Layer(int inputCount, int outputCount, {this.normalizationFunction = ActivationFunction.sigmoid}) {
    this.neurons ??= List<Neuron>();

    // Add a new list of weights for each neuron
    for (int i = 0; i < outputCount; i++) {
      this.neurons.add(
            Neuron(
              inputCount,
              normalizationFunction: this.normalizationFunction,
            ),
          );
    }
  }

  void changeNormalization(ActivationFunction n) => this.normalizationFunction = n;

  List<double> forwardPropagation(List<double> inputs) {
    for (Neuron neuron in neurons) {
      neuron.forwardPropagation(inputs);
    }

    return outputs;
  }

  void backPropagationOutput(List<double> expected) {
    for (int i = 0; i < neurons.length; i++) {
      neurons[i].backPropagationOutput(expected[i]);
    }
  }

  void backPropagationHidden(List<double> gammaForward, List<List<double>> weightsForward) {
    for (int i = 0; i < neurons.length; i++) {
      neurons[i].backPropagationHidden(gammaForward, weightsForward[i]);
    }
  }

  void updateWeights() {
    for (int i = 0; i < this.neurons.length; i++) {
      for (int j = 0; j < this.neurons[i].weights.length; j++) {
        neurons[i].weights[j] += neurons[i].weightAdj[j] * Layer.learningRate;
      }
    }
  }
}
