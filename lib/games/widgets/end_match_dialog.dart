import 'package:flutter/material.dart';

class EndMatchDialog extends StatelessWidget {
  final VoidCallback? onConfirm;
  const EndMatchDialog({super.key, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terminar Jogo'),
      content: const Text('Tens a certeza que queres terminar o jogo?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () { onConfirm?.call(); Navigator.pop(context); }, child: const Text('Confirmar')),
      ],
    );
  }
}
