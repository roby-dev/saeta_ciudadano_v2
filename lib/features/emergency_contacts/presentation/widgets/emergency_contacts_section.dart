import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../providers/emergency_contacts_provider.dart';

/// "Emergency contacts" card shown in the profile screen: lists the
/// current contacts (max [EmergencyContactsProvider.maxContacts]), lets the
/// user add one from the device contact picker or remove one, and exposes
/// the "send SMS to my emergency contacts on alert" switch (disabled while
/// there are no contacts).
class EmergencyContactsSection extends StatelessWidget {
  const EmergencyContactsSection({super.key});

  Future<void> _addContact(BuildContext context) async {
    final provider = context.read<EmergencyContactsProvider>();
    final added = await provider.addContactFromPicker();
    if (!context.mounted) return;
    if (!added && provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  Future<void> _removeContact(
    BuildContext context,
    EmergencyContactEntity contact,
  ) async {
    final provider = context.read<EmergencyContactsProvider>();
    final removed = await provider.removeContact(contact);
    if (!context.mounted) return;
    if (!removed && provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<EmergencyContactsProvider>();
    final canInteract = !provider.isSaving;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contactos de emergencia',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  tooltip: 'Agregar contacto',
                  onPressed: canInteract && provider.canAddContact
                      ? () => _addContact(context)
                      : null,
                ),
              ],
            ),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No tienes contactos de emergencia agregados.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              ...provider.contacts.map(
                (contact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.contact_phone_outlined),
                  title: Text(
                    contact.name.isNotEmpty ? contact.name : 'Sin nombre',
                  ),
                  subtitle: Text(contact.phone),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: canInteract
                        ? () => _removeContact(context, contact)
                        : null,
                  ),
                ),
              ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enviar SMS a mis contactos de emergencia'),
              subtitle: Text(
                provider.contacts.isEmpty
                    ? 'Agrega al menos un contacto para activar esta opción.'
                    : 'Se abrirá el mensajero del teléfono al enviar una alerta.',
              ),
              value: provider.sendSmsOnAlert,
              onChanged: provider.contacts.isEmpty
                  ? null
                  : (value) => provider.setSendSmsOnAlert(value),
            ),
          ],
        ),
      ),
    );
  }
}
