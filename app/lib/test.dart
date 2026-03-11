import 'package:flutter/material.dart';
import 'services/api_service.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Test API Makanan"),
        backgroundColor: Colors.orange,
      ),

      body: FutureBuilder(
        future: ApiService.getMakanan(),
        builder: (context, snapshot) {

          // loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // error
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          final data = snapshot.data as List;

          if (data.isEmpty) {
            return const Center(
              child: Text("Data makanan kosong"),
            );
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {

              final makanan = data[index];

              return ListTile(
                leading: const Icon(Icons.fastfood),
                title: Text(makanan['nama_makanan']),
                subtitle: Text(makanan['deskripsi'] ?? ''),
              );

            },
          );
        },
      ),
    );
  }
}