import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'dart:math';
import 'constants.dart';

class CustomTextField extends StatefulWidget {
	final String text; // Initial text content
	final int initialcursorIndex; // Initial cursor position
	final Color cursorColor; // Cursor color
	final TextEditingController controller; // TextEditingController
	final int cursorIndex; // Tracks cursor location

	const CustomTextField({
		super.key,
		this.text = '',
		this.initialcursorIndex = 0,
		this.cursorColor = Colors.yellow,
		required this.controller, // Required controller for text manipulation
		this.cursorIndex = 0,
	});

	@override
	State<CustomTextField> createState() => _CustomTextFieldState();
}


class _CustomTextFieldState extends State<CustomTextField>{
	late Offset tapPos; // Tracks cursor location
	bool showCursor = true; // Controls cursor blinking
	final FocusNode focusNode = FocusNode();
	late int cursorIndex;
	late int logicalCursorIndex;
	late int cursorIndexDiff;
	double textFieldHeight = 50; // Initial height
	bool isTapped = false;

	void updateHeight(double newHeight) {
		if (newHeight != textFieldHeight) {
			textFieldHeight = newHeight;
		}
	}
	
	void updateCursorIndex(int indexUpdate, int logicalIndexUpdate) {
		cursorIndex = indexUpdate;
		logicalCursorIndex = logicalIndexUpdate;
		
		// Explicitly update controller selection after cursor position is computed
		WidgetsBinding.instance.addPostFrameCallback((_) {
			widget.controller.selection = TextSelection.collapsed(offset: cursorIndex);
		});
	}
	
	void updateTapPosition(Offset tapPositionUpdate) {
		tapPos = tapPositionUpdate;
	}

	void updateTapState() {
		isTapped = false;
	}

	@override
	void initState() {
		super.initState();
		cursorIndex = widget.initialcursorIndex; // Set the initial cursor position
		logicalCursorIndex = widget.initialcursorIndex; // Set the initial cursor position
		tapPos = Offset.zero; // Set the initial tap position

		// Listener for text changes in the controller
		widget.controller.addListener(() {
			setState(() {
				// Update cursor position based on controller's selection
				cursorIndexDiff = widget.controller.selection.baseOffset - cursorIndex;
				cursorIndex = widget.controller.selection.baseOffset;

				print('$logicalCursorIndex, $cursorIndexDiff');
				logicalCursorIndex += cursorIndexDiff;
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

	
	@override
	void dispose() {
		widget.controller.dispose();
		focusNode.dispose();
		super.dispose();
	}
	
	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerUp: (event) {
				final RenderBox box = context.findRenderObject() as RenderBox;
				final Offset localPosition = box.globalToLocal(event.position);
				
				tapPos = localPosition;
				isTapped = true;
				// print('event pos ${event.position}, $tapPos');
				// print('controller ${widget.controller.text} ${widget.controller.text.length}');
				// cursorPos = cursorPos;
				
				FocusScope.of(context).requestFocus(focusNode); // Activate keyboard
			},
			child: AnimatedSize(
				curve: Curves.linear,
				duration: const Duration(milliseconds: 200),
				child: CustomPaint(
					painter: TextFieldPainter(
						widget.controller.text,
						cursorIndex,
						logicalCursorIndex,
						tapPos,
						showCursor,
						widget.cursorColor,
						updateCursorIndex,
						updateHeight,
						updateTapPosition,
						isTapped,
						updateTapState,
					),
					size: Size(30, textFieldHeight), // Set the size of the area where the text is rendered
					),
			),
		// ),
		);
	}
}

/// **CustomPainter for Rendering Text & Cursor**
class TextFieldPainter extends CustomPainter {
	final String text;
	late int cursorIndex; // Tracks cursor location
	late int logicalCursorIndex; // Tracks cursor location
	final Offset tapPos;
	final bool showCursor;
	final Color cursorColor;
	final Function(int, int) updateCursorIndex; // Callback to update cursorIndex
	final Function(double) updateHeight; // Callback to update height
	final Function(Offset) updateCursorPosition; // Callback to update height
	final bool isTapped;
	final Function updateTapState;

	final double paddingX = 10; // Horizontal padding
	final double paddingY = 10; // Vertical padding
	double textWidth = 0;

	// list for box objects
	List<Box> boxList = [];
	List<Offset> charOffset = [];

	TextFieldPainter(this.text, this.cursorIndex, this.logicalCursorIndex, this.tapPos, this.showCursor, this.cursorColor, this.updateCursorIndex, this.updateHeight, this.updateCursorPosition, this.isTapped, this.updateTapState);

	@override
	//     canvas.drawRect(Rect.fromLTWH(cursorX, offsetY, 2, 25), paint);
	//   }
	// }
	void paint(Canvas canvas, Size size) {
		double maxHeight = 40;  // Store max height of text elements
		int cursorIndexStart = 0;
		int logicalCursorIndexStart = 0;
		bool deonominatorPlaceholder = false;

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

		// add cursor zero position
		charOffset.add(Offset(offsetX, offsetY));

		double currentX = offsetX; // set current cursor to offset

		for (int i = 0; i < exprChunks.length; i++) {
			// print('in here all thet∈me');
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

				if (denominator == '') {
					denominator = '[  ]';
				}
				// print('numerator $numerator ${numerator.length}');
				// print('denominator $denominator ${denominator.length}');

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
				updateHeight(maxHeight+15); // Add some padding
				
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
				numeratorPainter.paint(canvas, Offset(numOffsetX + FRACTIONOFFSET, offsetY-numeratorPainter.height/2));
				// append to box
				Box numBox = Box(numerator, numOffsetX + FRACTIONOFFSET, offsetY-numeratorPainter.height/2, numeratorPainter.width, numeratorPainter.height, cursorIndexStart, logicalCursorIndexStart, 'numerator');
				boxList.add(numBox);
				charOffset.addAll(numBox.getCharsOffset());
				cursorIndexStart += numerator.length + 1;
				logicalCursorIndexStart += numerator.length + 1 + 1;

				// Draw the denominator
				denominatorPainter.paint(canvas, Offset(denOffsetX + FRACTIONOFFSET, offsetY+denominatorPainter.height/2));
				// append to box
				Box denBox = Box(denominator, denOffsetX + FRACTIONOFFSET, offsetY+denominatorPainter.height/2, denominatorPainter.width, denominatorPainter.height, cursorIndexStart, logicalCursorIndexStart, 'denominator');
				boxList.add(denBox);
				charOffset.addAll(denBox.getCharsOffset());

				// add inline end offset
				if (numeratorPainter.width >= denominatorPainter.width) {
					charOffset.add(Offset(charOffset[charOffset.length-denominator.length-2].dx, offsetY));
				} else {
					charOffset.add(Offset(charOffset[charOffset.length-1].dx, offsetY));
				}

				// hoping that the fraction is followed by a sign or number and not a division sign
				cursorIndexStart += denominator.length;
				logicalCursorIndexStart += denominator.length+1;
				
				if (denominator == '[  ]') {
					deonominatorPlaceholder = true;
				}

				// Draw the fraction line
				double lineWidth = max(numeratorPainter.width, denominatorPainter.width);
				final linePaint = Paint()..color = Colors.white;
				linePaint.strokeWidth = 2.0;

				double startX = min(numOffsetX, denOffsetX);
				double endX = startX + lineWidth + 2*FRACTIONOFFSET;

				canvas.drawLine(Offset(startX, offsetY+numeratorPainter.height/2), Offset(endX, offsetY+numeratorPainter.height/2), linePaint);
				
				// Move X position forward based on character width
				currentX += lineWidth + 2*FRACTIONOFFSET;
				textWidth += lineWidth;

				// add one for the division sign
				// cursorIndexStart += 1;
				
			} else {
				// Configure text painter
				final textPainter = TextPainter(
					text: TextSpan(text: chars, style: TextStyle(color: Colors.white, fontSize: FONTSIZE)),
					textAlign: TextAlign.center,
					textDirection: TextDirection.ltr,
				)..layout();

				// Notify parent widget if height has changed before proceeding
				maxHeight = maxHeight < textPainter.height ? textPainter.height : maxHeight;
				updateHeight(maxHeight+15); // Add some padding

				// Paint each character chunk at the computed position
				textPainter.paint(canvas, Offset(currentX, offsetY));
				// append to box
				Box textBox = Box(chars, currentX, offsetY, textPainter.width, textPainter.height, cursorIndexStart, logicalCursorIndexStart);
				boxList.add(textBox);

				// Move X position forward based on character width
				currentX += textPainter.width;
				charOffset.addAll(textBox.getCharsOffset());
				// print('char offset $chars, $cursorIndexStart');
				cursorIndexStart += chars.length;
				logicalCursorIndexStart += chars.length;
				textWidth += textPainter.width;
			}
		}
		
		// print('$cursorIndexStart ${charOffset}');

		// Paint cursor if visible
		if (showCursor) {
			if (cursorIndex >= 0) {
				if (isTapped) {
					// print('in here is tapped $isTapped');
					// print('box offset $charOffset $cursorIndex');
					bool boxFound = false;
					for (int ci=0; ci < boxList.length; ci++) {
						if (boxList[ci].inBox(tapPos)) {
							final paint = Paint()..color = cursorColor;
							canvas.drawRect(Rect.fromLTWH(boxList[ci].trueX, boxList[ci].offsetY , 2, 30), paint);
							
							cursorIndex = boxList[ci].trueCursorIndex;
							logicalCursorIndex = boxList[ci].trueLogicalCursorIndex;
							// logicalCursorIndex = cursorIndex;
							// if (boxList[ci].kind == 'numerator') {
							// 	logicalCursorIndex += 1;
							// } else if (boxList[ci].kind == 'denominator') {
							// 	logicalCursorIndex += 2;
							// }
							// print('here at cursorindextap $cursorIndex ${(boxList[ci].offsetX, boxList[ci].offsetY)}');
							boxFound = true;
							break;
						} else {
							
						}
					}
					if (!boxFound) {
						// print(' shoul not be  in here');
						if (tapPos.dx < offsetX) {
							// print('reached here $cursorIndex ($offsetX, $offsetY)');
							cursorIndex = 0;
							logicalCursorIndex = 0;
							final paint = Paint()..color = cursorColor;
							canvas.drawRect(Rect.fromLTWH(offsetX, offsetY , 2, 30), paint);
							// updateCursorPosition(Offset(offsetX, offsetY));
						} else {
							print('reached here instead $cursorIndex ($offsetX, $offsetY)');
							cursorIndex = cursorIndexStart;
							logicalCursorIndex = charOffset.length-1;
							final paint = Paint()..color = cursorColor;
							canvas.drawRect(Rect.fromLTWH(offsetX+textWidth, offsetY , 2, 30), paint);
							// updateCursorPosition(Offset(offsetX+textWidth, offsetY));
						}
					}
					print('from equatn ($cursorIndex, $logicalCursorIndex)');
					// print('$charOffset');
					updateCursorIndex(cursorIndex, logicalCursorIndex);
					updateTapState();
				} else {
					final paint = Paint()..color = cursorColor;
					// print('here at cursorindex ${(charOffset[cursorIndex].dx, charOffset[cursorIndex].dy)} $cursorIndex');
					// print('here before draaw $cursorIndex, $logicalCursorIndex');
					if (deonominatorPlaceholder) {
						canvas.drawRect(Rect.fromLTWH(charOffset[logicalCursorIndex+3].dx, charOffset[logicalCursorIndex+3].dy , 2, 30), paint);
					} else {
						canvas.drawRect(Rect.fromLTWH(charOffset[logicalCursorIndex].dx, charOffset[logicalCursorIndex].dy , 2, 30), paint);
					}
				}
			}
			updateCursorIndex(cursorIndex, logicalCursorIndex);
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

	List<String> splitExpression(String expression) {
		// print(expression);
		expression = expression.replaceAll(' ', '');
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
		// print(pseudoText);
		return pseudoText;
	}
}

class Box {
	final String chars;
	final double offsetX;
	final double offsetY;
	final double dx;
	final double dy;
	final int cursorIndex;
	final int logicalCursorIndex;
	late double trueX;
	late int trueCursorIndex;
	late int trueLogicalCursorIndex;
	final String kind;

	Box(this.chars, this.offsetX, this.offsetY, this.dx, this.dy, this.cursorIndex, this.logicalCursorIndex, [this.kind = 'inline']);
	
	List<Offset> getCharsOffset() {
		List<Offset> charsOffset = [];

		// calculate individual character offsets
		if (kind == 'inline'){
			double totalWidth = 0;
			for (int i=0; i < chars.length; i++){
				final textPainter = TextPainter(
						text: TextSpan(text: chars[i], style: TextStyle(color: Colors.white, fontSize: FONTSIZE)),
						textAlign: TextAlign.center,
						textDirection: TextDirection.ltr,
					)..layout();

				totalWidth += textPainter.width;
				charsOffset.add(Offset(offsetX+totalWidth, offsetY));
			}
		} else if (kind == 'numerator' || kind == 'denominator') {
			double totalWidth = 0;
			// add location just in front of the first text
			charsOffset.add(Offset(offsetX, offsetY));

			for (int i=0; i < chars.length; i++){
				final textPainter = TextPainter(
						text: TextSpan(text: chars[i], style: TextStyle(color: Colors.white, fontSize: FONTSIZE)),
						textAlign: TextAlign.center,
						textDirection: TextDirection.ltr,
					)..layout();

				totalWidth += textPainter.width;
				charsOffset.add(Offset(offsetX+totalWidth, offsetY));
			}
		} else if (kind == 'raise') {
			
		} else if (kind == 'sub') {

		}
		return charsOffset;
	}

	bool inBox(pos) {
		trueX = offsetX;

		bool leftRight = pos.dx >= offsetX && pos.dx <= offsetX + dx;
		bool topBottom = pos.dy >= offsetY && pos.dy <= offsetY + dy;
		
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
				// check if to place the cursor to the left or right of the box
				if (kind == 'numerator' || kind == 'numerator'){
					if (posX < currentX + textPainter.width/2) {
						trueCursorIndex = cursorIndex + i;
						trueLogicalCursorIndex = logicalCursorIndex + i + 1;
						return currentX;
					} else {
						// print('In here now now');
						trueCursorIndex = cursorIndex + i + 1;
						trueLogicalCursorIndex = logicalCursorIndex + i + 1 + 1;
						return textPainter.width + currentX;
					}
				} else {
					if (posX < currentX + textPainter.width/2) {
						trueCursorIndex = cursorIndex + i;
						trueLogicalCursorIndex = logicalCursorIndex + i;
						return currentX;
					} else {
						// print('In here now now');
						trueCursorIndex = cursorIndex + i + 1;
						trueLogicalCursorIndex = logicalCursorIndex + i + 1;
						return textPainter.width + currentX;
					}
				}
			} else {
				currentX += textPainter.width;
			}
		}
		print('In here now now56');
		trueCursorIndex = cursorIndex;
		return offsetX;
	}

}