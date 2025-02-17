import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'constants.dart';

class CustomTextField extends StatefulWidget {
	final String text; // Initial text content
	final int initialCursorPos; // Initial cursor position
	final Color cursorColor; // Cursor color
	final TextEditingController controller; // TextEditingController
	final int cursorPos; // Tracks cursor location

	const CustomTextField({
		super.key,
		this.text = '',
		this.initialCursorPos = 0,
		this.cursorColor = Colors.yellow,
		required this.controller, // Required controller for text manipulation
		this.cursorPos = 0,
	});

	@override
	_CustomTextFieldState createState() => _CustomTextFieldState();
}


class _CustomTextFieldState extends State<CustomTextField> {
	late Offset tapPosition; // Tracks cursor location
	bool showCursor = true; // Controls cursor blinking
	final FocusNode focusNode = FocusNode();
	late int cursorPos;
	double textFieldHeight = 40; // Initial height

	void updateHeight(double newHeight) {
		if (newHeight != textFieldHeight) {
			textFieldHeight = newHeight;
		}
	}

	@override
	void initState() {
		super.initState();
		cursorPos = widget.initialCursorPos; // Set the initial cursor position
		tapPosition = Offset.zero; // Set the initial cursor position

		// Listener for text changes in the controller
		widget.controller.addListener(() {
			setState(() {
				// Update cursor position based on controller's selection
				cursorPos = widget.controller.selection.baseOffset;
			});
		});

		// Blinking cursor
		Timer.periodic(const Duration(milliseconds: 500), (timer) {
			if (focusNode.hasFocus) {
				setState(() => showCursor = !showCursor);
			} else {
				setState(() => showCursor = false);
			}
		});
	}

	/// Inserts a character at the cursor position
	void insertText(String char) {
		setState(() {
			final text = widget.controller.text;
			widget.controller.text = text.substring(0, cursorPos) + char + text.substring(cursorPos);
			cursorPos++; // Move cursor forward
		});
	}

	/// Deletes the character before the cursor
	void deleteText() {
		if (cursorPos > 0) {
			setState(() {
				final text = widget.controller.text;
				widget.controller.text = text.substring(0, cursorPos - 1) + text.substring(cursorPos);
				cursorPos--; // Move cursor back
			});
		}
	}

	/// Moves the cursor left
	void moveCursorLeft() {
		if (cursorPos > 0) {
			setState(() => cursorPos--);
		}
	}

	/// Moves the cursor right
	void moveCursorRight() {
		if (cursorPos < widget.controller.text.length) {
			setState(() => cursorPos++);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerUp: (event) {
			final RenderBox box = context.findRenderObject() as RenderBox;
			final Offset localPosition = box.globalToLocal(event.position);
			
			tapPosition = localPosition; // Now tapPosition is relative to the widget
				// print(cursorPos);
				FocusScope.of(context).requestFocus(focusNode); // Activate keyboard
			},
				child: CustomPaint(
					painter: TextFieldPainter(
						widget.controller.text,
						cursorPos,
						tapPosition,
						showCursor,
						widget.cursorColor,
						widget.controller.selection.baseOffset,
						updateHeight,
					),
					size: Size(30, textFieldHeight), // Set the size of the area where the text is rendered
				),
			// ),
		);
	}
}

/// **CustomPainter for Rendering Text & Cursor**
class TextFieldPainter extends CustomPainter {
	final String text;
	late int cursorPos;
	final Offset tapPosition; // Tracks cursor location
	final bool showCursor;
	final Color cursorColor;
	late int controllerSelectionBaseOffset;
	final Function(double) onHeightChanged; // Callback to update height

	// list for box objects
	List<Box> boxList = [];

	TextFieldPainter(this.text, this.cursorPos, this.tapPosition, this.showCursor, this.cursorColor, this.controllerSelectionBaseOffset, this.onHeightChanged);

	@override
	//     canvas.drawRect(Rect.fromLTWH(cursorX, offsetY, 2, 25), paint);
	//   }
	// }
	void paint(Canvas canvas, Size size) {
		double maxHeight = 40;  // Store max height of text elements

		// get expression chunks
		List<String> exprChunks = splitExpression(text);

		// Get pseudo text which should be the same width as fraction formatted text
		String pseudoText = getPseudoText(exprChunks);

		final textPainterAll = TextPainter(
				text: TextSpan(text: pseudoText, style: TextStyle(color: Colors.white, fontSize: FONTSIZE)),
				textAlign: TextAlign.center,
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: size.width); // Ensure text doesn't overflow the container's widt

		// Calculate horizontal and vertical alignment offsets
		double offsetX = (size.width - textPainterAll.width) / 2;
		double offsetY = (size.height - textPainterAll.height) / 2;

		double currentX = offsetX; // set current cursor to offset

		for (int i = 0; i < exprChunks.length; i++) {
			String chars = exprChunks[i];

			// Iterate over each character and paint separately
			if (chars.contains('\u00F7')) {
				// get index of division symbol
				int index = chars.indexOf('\u00F7');
				String numerator;
				String denominator;

				if (index != -1 && index != 0) {
					numerator = chars.substring(0, index);
					denominator = chars.substring(index + 1);
				} else {
					// Configure fraction text painter
					numerator = '[  ]';
					denominator = '[  ]';
				}

				final numeratorPainter = TextPainter(
					text: TextSpan(text: numerator, style: const TextStyle(color: Colors.white, fontSize: FONTSIZE)),
					textDirection: TextDirection.ltr,
				)..layout();

				// Draw the denominator
				final denominatorPainter = TextPainter(
					text: TextSpan(text: denominator, style: const TextStyle(color: Colors.white, fontSize: FONTSIZE)),
					textDirection: TextDirection.ltr,
				)..layout();

				// Notify parent widget if height has changed before drawing the fraction
				maxHeight = maxHeight < numeratorPainter.height + denominatorPainter.height ? numeratorPainter.height + denominatorPainter.height : maxHeight;
				onHeightChanged(maxHeight+15); // Add some padding
				
				// calculate numerator and denominator offsets
				double numOffsetX;
				double denOffsetX;
				if (numeratorPainter.width >= denominatorPainter.width) {
					numOffsetX = currentX;
					denOffsetX = currentX + numeratorPainter.width/2 - denominatorPainter.width/2;
				} else {
					numOffsetX = currentX - numeratorPainter.width/2 + denominatorPainter.width/2;
					denOffsetX = currentX;
				}
				// Draw the numerator
				numeratorPainter.paint(canvas, Offset(numOffsetX, offsetY-numeratorPainter.height/2));
				// append to box
				boxList.add(Box(numerator, numOffsetX, offsetY-numeratorPainter.height/2, numeratorPainter.width, numeratorPainter.height));

				// Draw the denominator
				denominatorPainter.paint(canvas, Offset(denOffsetX, offsetY+denominatorPainter.height/2));
				// append to box
				boxList.add(Box(denominator, denOffsetX, offsetY+denominatorPainter.height/2, denominatorPainter.width, denominatorPainter.height));

				// Draw the fraction line
				double lineWidth = max(numeratorPainter.width, denominatorPainter.width);
				final linePaint = Paint()..color = Colors.white;
				linePaint.strokeWidth = 2.0;

				double startX = min(numOffsetX, denOffsetX);
				double endX = startX + lineWidth;

				canvas.drawLine(Offset(startX, offsetY+numeratorPainter.height/2), Offset(endX, offsetY+numeratorPainter.height/2), linePaint);
				
				// Move X position forward based on character width
				currentX += lineWidth;
				
			} else {
				// Configure text painter
				final textPainter = TextPainter(
					text: TextSpan(text: chars, style: TextStyle(color: Colors.white, fontSize: FONTSIZE)),
					textAlign: TextAlign.center,
					textDirection: TextDirection.ltr,
				)..layout();

				// Notify parent widget if height has changed before proceeding
				maxHeight = maxHeight < textPainter.height ? textPainter.height : maxHeight;
				onHeightChanged(maxHeight+15); // Add some padding

				// Paint each character chunk at the computed position
				textPainter.paint(canvas, Offset(currentX, offsetY));
				// append to box
				boxList.add(Box(chars, currentX, offsetY, textPainter.width, textPainter.height));

				// Move X position forward based on character width
				currentX += textPainter.width;
			}
		}

		// Paint cursor if visible
		if (showCursor) {
			for (int ci=0; ci < boxList.length; ci++) {
				
				if (boxList[ci].inBox(tapPosition)) {
					final paint = Paint()..color = cursorColor;
					canvas.drawRect(Rect.fromLTWH(boxList[ci].trueX, boxList[ci].offsetY , 2, 25), paint);
					// controllerSelectionBaseOffset = boxList[ci].trueX;
					break;
				} else {
					
				}
			}
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

	List<String> splitExpression(String expression) {
		// Regular expression to match +, -, (, and ) while keeping them in the result
		final RegExp regex = RegExp(r'(\+|-|\(|\))');
		
		// Split the expression but keep the delimiters in the result using capturing groups
		List<String> parts = expression.splitMapJoin(
			regex,
			onMatch: (match) => match.group(0)!, // Keep the match in the result
			onNonMatch: (nonMatch) => nonMatch, // Keep non-matching parts as well
		).split(''); // Split into individual characters

		List<String> result = [];
		String currentPart = '';
		
		// Loop through the characters and build the expression parts
		for (var char in parts) {
			if (char == '+' || char == '-' || char == '(' || char == ')') {
			if (currentPart.isNotEmpty) {
				result.add(currentPart); // Add the previous part (number or operator before)
				currentPart = '';
			}
			result.add(char); // Add the operator or parenthesis
			} else {
			currentPart += char; // Add to the current part (number or other)
			}
		}

		if (currentPart.isNotEmpty) {
			result.add(currentPart); // Add the final part if exists
		}
		// print(result);
		return result;
	}

	String getPseudoText(List<String> chunks) {
		String pseudoText = '';

		for (int i=0; i < chunks.length; i++) {
			if (chunks[i].contains('\u00F7')) {
				// Split the string at the separator
				List<String> parts = chunks[i].split('\u00F7');
				if (parts.length == 2) {
					// Get the lengths of both parts
					pseudoText += parts[0].length > parts[1].length ? parts[0] : parts[1];
				}
			} else {
				pseudoText += chunks[i];
			}
		}
		return pseudoText;
	}
}

class Box {
	final String chars;
	final double offsetX;
	final double offsetY;
	final double dx;
	final double dy;
	late double trueX;

	Box(this.chars, this.offsetX, this.offsetY, this.dx, this.dy);
	
	bool inBox(pos) {
		trueX = offsetX;

		bool leftRight = pos.dx >= offsetX && pos.dx <= offsetX + dx;
		bool topBottom = pos.dy >= offsetY && pos.dy <= offsetY + dy;
		// debugPrint('$offsetX, $offsetY, $dx, $dy, $leftRight, $topBottom');
		if (leftRight && topBottom){
			trueX = setTrueX(chars, pos.dx);
			return true;
		} else {
			return false;
		}
	}

	double setTrueX(chars, posX) {
		double currentX = offsetX;
		for (int i=0; i < chars.length; i++) {
			final textPainter = TextPainter(
					text: TextSpan(text: chars[i], style: TextStyle(color: Colors.white, fontSize: FONTSIZE)),
					textAlign: TextAlign.center,
					textDirection: TextDirection.ltr,
				)..layout();

			if (posX >= currentX && posX <= currentX + textPainter.width) {
				return (posX~/currentX) * textPainter.width + currentX;
			} else {
				currentX += textPainter.width;
			}
		}
		return offsetX;
	}

}