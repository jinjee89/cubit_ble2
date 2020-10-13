import 'package:flutter/material.dart';

class Field extends StatelessWidget {
  final String label;
  final String value;
  final int leftFlex;
  final int rightFlex;
  const Field({this.label, this.value, this.leftFlex = 1, this.rightFlex = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: leftFlex,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ),
        Expanded(
          flex: rightFlex,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.red[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
