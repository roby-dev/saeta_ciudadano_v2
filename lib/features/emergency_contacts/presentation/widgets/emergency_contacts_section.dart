import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../providers/emergency_contacts_provider.dart';
import '../utils/contact_initials.dart';

/// "Contactos de emergencia" card shown in the profile screen: lists the
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
    final provider = context.watch<EmergencyContactsProvider>();
    final canInteract = !provider.isSaving;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contactos de emergencia',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: canInteract && provider.canAddContact
                    ? () => _addContact(context)
                    : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${provider.contacts.length} de '
            '${EmergencyContactsProvider.maxContacts} contactos',
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          if (provider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tienes contactos de emergencia agregados.',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            )
          else
            ...provider.contacts.map(
              (contact) => _ContactRow(
                contact: contact,
                enabled: canInteract,
                onRemove: () => _removeContact(context, contact),
              ),
            ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Enviar SMS al reportar una alerta',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            subtitle: Text(
              provider.contacts.isEmpty
                  ? 'Agrega al menos un contacto para activar esta opción.'
                  : 'Se abrirá el mensajero del teléfono con tus contactos.',
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
            value: provider.sendSmsOnAlert,
            onChanged: provider.contacts.isEmpty
                ? null
                : (value) => provider.setSendSmsOnAlert(value),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.enabled,
    required this.onRemove,
  });

  final EmergencyContactEntity contact;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              contactInitials(contact.name),
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name.isNotEmpty ? contact.name : 'Sin nombre',
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Quitar contacto',
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}
