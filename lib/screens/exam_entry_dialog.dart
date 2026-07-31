import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/exam_timetable_entry.dart';
import '../providers/timetable_provider.dart';
import 'package:provider/provider.dart';

class ExamEntryDialog extends StatefulWidget {
  final ExamTimetableEntry? entry;

  const ExamEntryDialog({super.key, this.entry});

  @override
  State<ExamEntryDialog> createState() => _ExamEntryDialogState();
}

class _ExamEntryDialogState extends State<ExamEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _subjectCodeCtrl;
  late TextEditingController _subjectNameCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _seatNoCtrl;
  late TextEditingController _sessionNoCtrl;
  late TextEditingController _examTypeCtrl;

  File? _imageFile;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _subjectCodeCtrl =
        TextEditingController(text: widget.entry?.subjectCode ?? '');
    _subjectNameCtrl =
        TextEditingController(text: widget.entry?.subjectName ?? '');
    _locationCtrl = TextEditingController(text: widget.entry?.location ?? '');
    _dateCtrl = TextEditingController(text: widget.entry?.date ?? '');
    _timeCtrl = TextEditingController(text: widget.entry?.time ?? '');
    _seatNoCtrl = TextEditingController(text: widget.entry?.seatNo ?? '');
    _sessionNoCtrl = TextEditingController(text: widget.entry?.sessionNo ?? '');
    _examTypeCtrl = TextEditingController(text: widget.entry?.examType ?? 'Final Exam');
  }

  @override
  void dispose() {
    _subjectCodeCtrl.dispose();
    _subjectNameCtrl.dispose();
    _locationCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _seatNoCtrl.dispose();
    _sessionNoCtrl.dispose();
    _examTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _processImage(_imageFile!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() => _isProcessing = true);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      List<TextLine> allLines = [];
      for (var block in recognizedText.blocks) {
        allLines.addAll(block.lines);
      }

      if (allLines.isEmpty) {
        textRecognizer.close();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image.')),
          );
        }
        return;
      }

      // Group lines by Y coordinate to form rows (assuming table-like structure)
      allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      List<List<TextLine>> rows = [];
      for (var line in allLines) {
        if (rows.isEmpty) {
          rows.add([line]);
        } else {
          var lastRow = rows.last;
          var lastRowY =
              lastRow.map((e) => e.boundingBox.top).reduce((a, b) => a + b) /
                  lastRow.length;
          var threshold = line.boundingBox.height * 0.8;
          if ((line.boundingBox.top - lastRowY).abs() < threshold) {
            lastRow.add(line);
          } else {
            rows.add([line]);
          }
        }
      }

      // Sort each row left-to-right by X coordinate
      for (var row in rows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      }

      List<ExamTimetableEntry> extractedExams = [];

      for (var row in rows) {
        String fullRowText = row.map((e) => e.text).join(' ');

        // Skip header row
        if (fullRowText.toLowerCase().contains('subject code') ||
            fullRowText.toLowerCase().contains('seat no')) {
          continue;
        }

        String subjectCode = '';
        String subjectName = '';
        String location = '';
        String date = '';
        String time = '';
        String seatNo = '';
        String sessionNo = '';

        // Basic heuristic parsing across the row elements
        for (var l in row) {
          final lText = l.text.trim();
          final lLower = lText.toLowerCase();

          if (lText.contains(RegExp(r'^\w{2}\d{4}'))) {
            subjectCode = lText.split(' ').first;
          } else if (lText.contains(RegExp(r'\d{1,2}(th|st|nd|rd)')) ||
              lText.contains(RegExp(r'\d{4}')) || lLower.contains('jan') || lLower.contains('feb') || lLower.contains('mar') || lLower.contains('apr') || lLower.contains('may') || lLower.contains('jun') || lLower.contains('jul') || lLower.contains('aug') || lLower.contains('sep') || lLower.contains('oct') || lLower.contains('nov') || lLower.contains('dec')) {
            if (date.isEmpty)
              date = lText;
            else
              date += ' $lText';
          } else if (lLower.contains('am') || lLower.contains('pm') || lText.contains(':')) {
            if (time.isEmpty)
              time = lText;
            else
              time += ' $lText';
          } else if (lText.startsWith('G') && lText.length == 5) {
            location = lText;
          } else if (lLower.contains('session')) {
            sessionNo = lText;
          } else if (int.tryParse(lText) != null) {
            seatNo = lText;
          } else if (lText.length > 5 &&
              subjectName.isEmpty &&
              !lText.contains(RegExp(r'\d'))) {
            subjectName = lText;
          }
        }

        if (subjectCode.isNotEmpty) {
          extractedExams.add(ExamTimetableEntry(
            subjectCode: subjectCode,
            subjectName: subjectName,
            location: location,
            date: date,
            time: time,
            seatNo: seatNo,
            sessionNo: sessionNo,
            examType: _examTypeCtrl.text.isNotEmpty ? _examTypeCtrl.text : 'Final Exam',
          ));
        }
      }

      textRecognizer.close();

      if (mounted) {
        if (extractedExams.length > 1) {
          final provider = context.read<TimetableProvider>();
          for (var ex in extractedExams) {
            provider.addExamEntry(ex);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Successfully extracted and saved ${extractedExams.length} exams!')),
          );
          Navigator.of(context).pop();
        } else if (extractedExams.length == 1) {
          final ex = extractedExams.first;
          _subjectCodeCtrl.text = ex.subjectCode;
          _subjectNameCtrl.text = ex.subjectName;
          _locationCtrl.text = ex.location;
          _dateCtrl.text = ex.date;
          _timeCtrl.text = ex.time;
          _seatNoCtrl.text = ex.seatNo;
          _sessionNoCtrl.text = ex.sessionNo;
          _examTypeCtrl.text = ex.examType;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Exam details extracted! Please review.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Could not extract specific exam rows. Try manual entry.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final entry = ExamTimetableEntry(
        id: widget.entry?.id,
        subjectCode: _subjectCodeCtrl.text.trim(),
        subjectName: _subjectNameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        date: _dateCtrl.text.trim(),
        time: _timeCtrl.text.trim(),
        seatNo: _seatNoCtrl.text.trim(),
        sessionNo: _sessionNoCtrl.text.trim(),
        examType: _examTypeCtrl.text.trim().isEmpty ? 'Final Exam' : _examTypeCtrl.text.trim(),
      );

      final provider = context.read<TimetableProvider>();
      if (widget.entry == null) {
        provider.addExamEntry(entry);
      } else {
        provider.updateExamEntry(entry);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.entry == null
                      ? 'Add Exam Timetable'
                      : 'Edit Exam Timetable',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_imageFile != null && !_isProcessing)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_imageFile!,
                          height: 150, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _examTypeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Exam Type (e.g. Final Exam, Mid Exam)', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectCodeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Subject Code', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Subject Name', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Location', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Date', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _timeCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Time', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _seatNoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Seat No', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sessionNoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Session No',
                            border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
