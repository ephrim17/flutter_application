import 'package:flutter/material.dart';
import 'package:flutter_application/shopping_list_app/model/groceries_data.dart';
import 'package:flutter_application/shopping_list_app/widgets/new_item.dart';
import 'package:google_fonts/google_fonts.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key, required this.restartApp});
  final void Function(String value) restartApp;

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  
  @override
  Widget build(BuildContext context) {
  
    void addNewItem() {
      showModalBottomSheet(
        isScrollControlled: true,
        context: context, 
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) {
          return NewItem();
      });
    } 

   return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        actions: [
          IconButton(onPressed: () => widget.restartApp('app-start-screen'), icon: const Icon(Icons.home)),
          IconButton(onPressed: (){
            addNewItem();
          }, icon: const Icon(Icons.add_shopping_cart)),
        ],
        title: Text(
          "Shopping List",
          style: GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
      body: ListView.builder(itemBuilder: itemBuilder, itemCount: groceryItems.length),
    );
  }

  Widget itemBuilder(BuildContext context, int index) {
    final item = groceryItems[index];
    return ListTile(
      title: Text(item.name),
      leading: CircleAvatar(
        backgroundColor: item.category.color,
      ),
      trailing: Text('x${item.quantity}'),
      subtitle: Text('Quantity: ${item.quantity}, Category: ${item.category.name}'),
    );
  }
}