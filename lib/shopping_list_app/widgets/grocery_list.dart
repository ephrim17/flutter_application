import 'package:flutter/material.dart';
import 'package:flutter_application/https_service/https_service_class.dart';
import 'package:flutter_application/shopping_list_app/model/groceries_data.dart';
import 'package:flutter_application/shopping_list_app/model/grocery_model.dart';
import 'package:flutter_application/shopping_list_app/widgets/new_item.dart';
import 'package:google_fonts/google_fonts.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key, required this.restartApp});
  final void Function(String value) restartApp;

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {

  Widget? noItemsWidget() {
    return Center(
      child: Text(
        'No items added yet!',
        style: GoogleFonts.aBeeZee(
          fontSize: 20,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
    );
  }

  Widget buildGroceryList() {
    return ListView.builder(
      itemCount: groceryItems.length,
      itemBuilder: itemBuilder,
    );
  }
  
  @override
  Widget build(BuildContext context) {
  
    void addNewItem() async {
      final newItem = await showModalBottomSheet<GroceryItem>(
        isScrollControlled: true,
        context: context, 
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) {
          return NewItem();
        },
      );
      if (newItem != null) {
        final http = HttpsService();
        await http.addShoppingList(newItem);
        setState(() {
          groceryItems.add(newItem);
        });
      }
    }

    void refreshItemLists() async {
      final http = HttpsService();
      final loadedEntries = await http.getGroceryItems();
      for (final item in loadedEntries) {
        print(item.name);
      }
    }

  var content = groceryItems.isEmpty ? noItemsWidget() : buildGroceryList();

   return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        actions: [
          IconButton(onPressed: () => widget.restartApp('app-start-screen'), icon: const Icon(Icons.home)),
          IconButton(onPressed: (){
            addNewItem();
          }, icon: const Icon(Icons.add_shopping_cart)),
          IconButton(onPressed: (){
            refreshItemLists();
          }, icon: const Icon(Icons.refresh)),
        ],
        title: Text(
          "Shopping List",
          style: GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
      body: content,
    );
  }

  Widget itemBuilder(BuildContext context, int index) {
    final item = groceryItems[index];
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(color: Colors.redAccent),
      onDismissed: (direction) {
        setState(() {
          groceryItems.removeAt(index);
        });
      },
      child: ListTile(
        title: Text(item.name),
        leading: CircleAvatar(
          backgroundColor: item.category.color,
        ),
        trailing: Text('x${item.quantity}'),
        subtitle: Text('category: ${item.category.name}'),
      ),
    );
  }
}