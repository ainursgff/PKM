import 'package:flutter/material.dart';

class EditIngredientsSheet extends StatefulWidget {
  final List<String> initialIngredients;
  final Function(List<String>) onSave;

  const EditIngredientsSheet({
    super.key,
    required this.initialIngredients,
    required this.onSave,
  });

  @override
  State<EditIngredientsSheet> createState() => _EditIngredientsSheetState();
}

class _EditIngredientsSheetState extends State<EditIngredientsSheet> {
  late List<String> ingredients;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    ingredients = List.from(widget.initialIngredients);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final text = _controller.text.trim().toUpperCase();
    if (text.isNotEmpty && !ingredients.contains(text)) {
      setState(() {
        ingredients.add(text);
        _controller.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      ingredients.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Edit Bahan",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Tambah bahan baru...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black45,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addIngredient(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF57C00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _addIngredient,
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ingredients.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        "Belum ada bahan. Silakan tambah.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: ingredients.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant, color: Color(0xFFF57C00), size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ingredients[index],
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeIngredient(index),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                widget.onSave(ingredients);
                Navigator.pop(context);
              },
              child: const Text(
                "Simpan Perubahan",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}
