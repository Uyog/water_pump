import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CustomAlertDialog extends StatelessWidget {
  final String lottiePath;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onButtonPressed;

  const CustomAlertDialog({
    super.key,
    required this.lottiePath,
    required this.title,
    required this.message,
    this.buttonText = "OK",
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.03,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie Animation
            SizedBox(
              height: screenHeight * 0.2,
              child: Lottie.asset(
                lottiePath,
                fit: BoxFit.contain,
                repeat: false,
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: screenHeight * 0.025,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.01),
            // Message
            Text(
              message,
              style: TextStyle(fontSize: screenHeight * 0.02),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            // Button
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.2,
                  vertical: screenHeight * 0.015,
                ),
              ),
              child: Text(
                buttonText,
                style: TextStyle(fontSize: screenHeight * 0.02),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
