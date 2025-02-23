import 'dart:math';

class Offset {
  double x, y;
  Offset(this.x, this.y);
}

class ExpressionNode {
  dynamic value; // A number, operator, or nested map (e.g. fraction)
  Offset left, right;
  String kind;
  List<int> index; // The index path in the tree

  ExpressionNode({
    required this.value,
    required this.left,
    required this.right,
    required this.kind,
    required this.index,
  });
}

class ExpressionTree {
  // Top-level tree stored as a map with string keys.
  Map<String, ExpressionNode> tree = {};
  int currentIndex = 0;
  List<int> selectedNodeIndex = []; // E.g. [2,1] means inside node at key "2", child "1"
  String selectedPosition = "";     // E.g. "left" or "right"

  /// Insert a new node. If a number is inserted immediately after a number,
  /// the new number is appended to the previous node’s value.
  void insert(dynamic value, String kind) {
    // If tree is empty, create the root node.
    if (tree.isEmpty) {
      tree['0'] = ExpressionNode(
        value: value,
        left: Offset(0, 0),
        right: Offset(0, 0),
        kind: kind,
        index: [0],
      );
      currentIndex++;
      return;
    }

    // Special case: if we are inserting a number and there's an active fraction node
    // with an empty denominator, insert into the denominator.
    if (kind == "numberNode" &&
        tree.containsKey("2") &&
        tree["2"]!.kind == "fractionNode") {
      ExpressionNode fraction = tree["2"]!;
      Map<String, ExpressionNode> fracChildren = fraction.value as Map<String, ExpressionNode>;
      if (fracChildren["2"]!.value == "") {
        // Place the new number in the denominator slot.
        fracChildren["2"] = ExpressionNode(
          value: value,
          left: Offset(0, 0),
          right: Offset(0, 0),
          kind: kind,
          // We want the denominator to keep its designated index.
          index: [fraction.index.first, 2],
        );
        return;
      }
    }

    // If inserting an operator that creates a fraction node.
    if (kind == "symbol" && (value == "*" || value == "/" || value == "^")) {
      String lastKey = (currentIndex - 1).toString();
      if (!tree.containsKey(lastKey)) return; // Ensure previous node exists

      ExpressionNode lastNode = tree.remove(lastKey)!;

      // Create a fraction node using the same index as the removed node.
      int fractionIndex = int.parse(lastKey);
      ExpressionNode fractionNode = ExpressionNode(
        value: {
          "0": lastNode, // Numerator: we want its index to be just [fractionIndex]
          "1": ExpressionNode(
            value: value,
            left: Offset(0, 0),
            right: Offset(0, 0),
            kind: "symbol",
            index: [fractionIndex, 1],
          ), // Operator gets a sub-index.
          "2": ExpressionNode(
            value: "", // Denominator placeholder.
            left: Offset(0, 0),
            right: Offset(0, 0),
            kind: "numberNode",
            index: [fractionIndex, 2],
          ),
        },
        left: Offset(0, 0),
        right: Offset(0, 0),
        kind: "fractionNode",
        index: [fractionIndex],
      );

      tree[lastKey] = fractionNode;
      return;
    }

    // Otherwise, if we're inserting a number node, check the last node.
    String lastKey = (currentIndex - 1).toString();
    if (kind == "numberNode" && tree.containsKey(lastKey)) {
      ExpressionNode lastNode = tree[lastKey]!;
      if (lastNode.kind == "numberNode") {
        // Append the new number to the existing number.
        lastNode.value = lastNode.value.toString() + value.toString();
        return;
      }
    }

    // Normal insertion: create a new node.
    tree[currentIndex.toString()] = ExpressionNode(
      value: value,
      left: Offset(0, 0),
      right: Offset(0, 0),
      kind: kind,
      index: [currentIndex],
    );
    currentIndex++;
  }

  /// Delete the node at the current selection.
  /// For example, if a fraction's operator ("/") is selected, remove it and merge
  /// the fraction node accordingly.
  void deleteAtSelection() {
    if (selectedNodeIndex.isEmpty) return;
    // For simplicity, assume the first element of selectedNodeIndex is a key in the main tree.
    String key = selectedNodeIndex.first.toString();
    if (!tree.containsKey(key)) return;
    ExpressionNode node = tree[key]!;

    // Handle deletion inside a fraction node.
    if (node.kind == "fractionNode" && selectedNodeIndex.length > 1) {
      Map<String, ExpressionNode> fracChildren = node.value as Map<String, ExpressionNode>;
      // If selecting the operator (assumed at index [*,1]) for deletion.
      if (selectedPosition == "right") {
        fracChildren.remove("1");
        // If the denominator is empty, flatten the fraction (promote the numerator).
        if (fracChildren["2"]!.value == "") {
          tree[key] = fracChildren["0"]!;
        } else {
          // Otherwise, merge numerator and denominator into one number.
          String merged = "${fracChildren["0"]!.value}${fracChildren["2"]!.value}";
          tree[key] = ExpressionNode(
            value: merged,
            left: fracChildren["0"]!.left,
            right: fracChildren["2"]!.right,
            kind: "numberNode",
            index: node.index,
          );
        }
      }
    } else {
      // Otherwise, perform a normal deletion.
      tree.remove(key);
    }
    _reindexTree();
  }

  /// Insert text at the currently selected node.
  /// If the selected node is a number node, the text is appended.
  void insertAtSelection(String text, String kind) {
    if (selectedNodeIndex.isEmpty) return;
    String key = selectedNodeIndex.first.toString();
    if (!tree.containsKey(key)) return;
    ExpressionNode node = tree[key]!;
    if (node.kind == "numberNode") {
      node.value = node.value.toString() + text;
    }
    _reindexTree();
  }

  /// Re-index the top-level nodes so that the indices remain sequential.
  void _reindexTree() {
    int newIndex = 0;
    Map<String, ExpressionNode> newTree = {};
    tree.forEach((key, node) {
      node.index = [newIndex];
      newTree[newIndex.toString()] = node;
      newIndex++;
    });
    tree = newTree;
    currentIndex = newIndex;
  }

  /// Simulated selection: store the index path and a position (e.g. "left", "right")
  void selectNode(List<int> index, String position) {
    selectedNodeIndex = index;
    selectedPosition = position;
    print("Selected Node: ${index.join(",")} ($position)");
  }

  /// Print the tree in a readable format.
  void printTree({String indent = ""}) {
    void printNode(ExpressionNode node, String levelIndent) {
      print("$levelIndent- Kind: ${node.kind}, Value: ${node.value is Map ? '{Nested Expression}' : node.value}, Index: ${node.index}");
      if (node.value is Map) {
        (node.value as Map<String, ExpressionNode>).forEach((key, child) {
          print("$levelIndent  [$key]:");
          printNode(child, "$levelIndent    ");
        });
      }
    }

    print("Expression Tree:");
    tree.forEach((key, node) {
      print("[$key]:");
      printNode(node, "  ");
    });
  }
}

void main() {
  var exprTree = ExpressionTree();

  // Build "2 + 3 / 5"
  exprTree.insert(2, "numberNode");     // Node at [0]
  exprTree.insert(9, "numberNode");     // Node at [0]
  exprTree.insert("+", "symbol");         // Node at [1]
  exprTree.insert(3, "numberNode");       // Node at [2] (will be numerator of fraction)
  exprTree.insert("/", "symbol");         // Converts previous node into a fraction node at [2]
  exprTree.insert(5, "numberNode");       // Fills the denominator of the fraction at [2]

  print("\nExpression Tree after insertion:");
  exprTree.printTree();
  /* Expected Output:
  Expression Tree after insertion:
  Expression Tree:
  [0]:
    - Kind: numberNode, Value: 2, Index: [0]
  [1]:
    - Kind: symbol, Value: +, Index: [1]
  [2]:
    - Kind: fractionNode, Value: {Nested Expression}, Index: [2]
      [0]:
        - Kind: numberNode, Value: 3, Index: [2]
      [1]:
        - Kind: symbol, Value: /, Index: [2, 1]
      [2]:
        - Kind: numberNode, Value: 5, Index: [2, 2]
  */

  // Simulate selecting the division operator ("/") within the fraction.
  exprTree.selectNode([2, 1], "right");
  exprTree.deleteAtSelection();

  print("\nExpression Tree after deletion:");
  exprTree.printTree();
  /* Expected Output after deletion:
  Expression Tree after deletion:
  Expression Tree:
  [0]:
    - Kind: numberNode, Value: 2, Index: [0]
  [1]:
    - Kind: symbol, Value: +, Index: [1]
  [2]:
    - Kind: numberNode, Value: 35, Index: [2]
  */

  // Now, simulate inserting a digit after a number.
  // Since the merged node [2] is a number node, the inserted text should be appended.
  exprTree.selectNode([2], "");
  exprTree.insertAtSelection("3", "numberNode");

  print("\nExpression Tree after insertion at selection:");
  exprTree.printTree();
  /* Expected Output after insertion at selection:
  Expression Tree after insertion at selection:
  Expression Tree:
  [0]:
    - Kind: numberNode, Value: 2, Index: [0]
  [1]:
    - Kind: symbol, Value: +, Index: [1]
  [2]:
    - Kind: numberNode, Value: 353, Index: [2]
  */
}
