/// Realtime updates from the backend's Socket.IO gateway
/// (`saeta-backend-v2/src/realtime/presentation/gateways/realtime.gateway.ts`).
///
/// A citizen socket only ever receives two events, both scoped server-side
/// to rooms this user was auto-joined to on connect: `updatedAlert` (an
/// alert this user owns changed) and `disableUser` (an admin disabled this
/// account; the server force-disconnects right after emitting it). Citizens
/// never emit anything to the server.
abstract class RealtimeService {
  /// Raw `updatedAlert` payloads as received from the server.
  ///
  /// This is intentionally the raw JSON map, not a parsed
  /// `CitizenAlertEntity`: the backend broadcasts its internal domain
  /// entity, whose `typeId`/`stateId` are plain ids (not the populated
  /// `type`/`state` objects the REST list endpoint returns). Consumers
  /// should treat an event as a "something changed" signal and refetch via
  /// REST rather than render this payload directly.
  Stream<Map<String, dynamic>> get updatedAlerts;

  /// Connects using the currently stored access token. A no-op when there
  /// is no session (no stored token).
  Future<void> connect();

  /// Disconnects the socket. Must be called on logout and on session
  /// expiry so a stale connection doesn't linger.
  Future<void> disconnect();
}
