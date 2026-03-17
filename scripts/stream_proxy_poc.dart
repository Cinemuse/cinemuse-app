import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

/// A Proof of Concept for a "Seamless" Streaming Proxy.
/// Version 8: Continuity Counter (CC) Remastering + Global Time Offsetting.
void main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 52566);
  print('--- Streaming Proxy POC (REMASTERED V8) ---');
  print('Goal: Eliminate glitches by fixing Continuity Counters and Timecodes.');
  print('1. Open VLC');
  print('2. Play Network Stream: http://localhost:${server.port}/proxy');
  print('---------------------------');

  final links = [
    'http://euroturk4.xyz:8080/play/live.php?mac=00:1A:79:A3:B7:95&stream=592676&extension=ts',
    'http://euroturk4.xyz:8080/play/live.php?mac=00:1A:79:A0:FF:4C&stream=592676&extension=ts',
  ];

  await for (HttpRequest request in server) {
    if (request.uri.path == '/proxy') {
      print('\n[Proxy] New request received.');
      await handleProxyRequest(request, links);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }
}

Future<void> handleProxyRequest(HttpRequest request, List<String> links) async {
  final response = request.response;
  response.bufferOutput = false; 
  response.headers.contentType = ContentType('video', 'mp2t');

  final client = HttpClient();
  client.connectionTimeout = Duration(seconds: 10);

  int currentLinkIndex = 0;
  
  // --- STATE PERSISTENCE ACROSS LINKS ---
  Map<int, int> lastCcMap = {}; // PID -> Last Continuity Counter (0-15)
  int? lastGlobalPTS;
  int ptsOffset = 0;

  while (currentLinkIndex < links.length) {
    final url = links[currentLinkIndex];
    print('[Proxy] Connecting to Link ${currentLinkIndex + 1}...');

    try {
      final proxyRequest = await client.getUrl(Uri.parse(url));
      proxyRequest.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/83.0');
      
      final proxyResponse = await proxyRequest.close();

      if (proxyResponse.statusCode == 200) {
        print('[Proxy] Stitching Link ${currentLinkIndex + 1} with CC Remastering...');
        
        BytesBuilder packetBuffer = BytesBuilder();
        int? stitchMatchPTS;
        bool isStitching = lastGlobalPTS != null;
        
        // Force failover every 20 seconds to test the stitch
        final startTime = DateTime.now();
        final testLimit = Duration(seconds: 20);

        await for (var data in proxyResponse) {
          packetBuffer.add(data);
          
          while (packetBuffer.length >= 188) {
            Uint8List bytes = packetBuffer.takeBytes();
            
            // Align to 0x47
            int syncIndex = bytes.indexOf(0x47);
            if (syncIndex == -1) continue;
            if (syncIndex + 188 > bytes.length) {
              packetBuffer.add(bytes.sublist(syncIndex));
              break;
            }
            
            Uint8List packet = bytes.sublist(syncIndex, syncIndex + 188);
            if (syncIndex + 188 < bytes.length) packetBuffer.add(bytes.sublist(syncIndex + 188));

            // A. EXTRACT METADATA
            int pid = ((packet[1] & 0x1F) << 8) | packet[2];
            int? packetPTS = _extractPTS(packet);
            bool hasPayload = (packet[3] & 0x10) != 0;

            // B. DEDUPLICATION / STITCHING
            if (isStitching) {
              if (packetPTS != null) {
                // If this PTS is older than or equal to our last sent, skip it to avoid duplication
                if (packetPTS <= lastGlobalPTS!) {
                  continue; 
                } else {
                  print('[Proxy] PTS Sync Achieved! Link ${currentLinkIndex + 1} is now ahead.');
                  isStitching = false;
                }
              } else if (pid != 0) {
                // Skip non-critical packets during stitch if we haven't found the time-sync yet
                continue; 
              }
            }

            // C. REMASTER CONTINUITY COUNTERS
            // This is the most important part for "dirty" artifacts.
            // We force every PID to have a perfect 0-15 sequence, ignoring what the link says.
            if (hasPayload) {
              int lastCc = lastCcMap[pid] ?? ((packet[3] & 0x0F) - 1);
              int nextCc = (lastCc + 1) & 0x0F;
              packet[3] = (packet[3] & 0xF0) | nextCc;
              lastCcMap[pid] = nextCc;
            }

            // D. UPDATE GLOBAL TRACKING
            if (packetPTS != null) {
              lastGlobalPTS = packetPTS;
            }

            // E. SEND TO PLAYER
            response.add(packet);
          }
          
          if (DateTime.now().difference(startTime) > testLimit) {
            print('[Proxy] --- FORCING FAILOVER TO TEST REMASTERED STITCH ---');
            break;
          }
        }
      }
    } catch (e) {
      print('[Proxy] Error: $e');
    }

    currentLinkIndex = (currentLinkIndex + 1) % links.length;
    await Future.delayed(Duration(milliseconds: 100));
  }

  await response.close();
  client.close();
}

int? _extractPTS(Uint8List packet) {
  bool pusi = (packet[1] & 0x40) != 0;
  if (!pusi) return null;
  int payloadOffset = 4;
  int afc = (packet[3] & 0x30) >> 4;
  if (afc == 2 || afc == 3) payloadOffset += 1 + packet[4];
  if (payloadOffset >= 188 - 14) return null;
  if (packet[payloadOffset] == 0x00 && packet[payloadOffset + 1] == 0x00 && packet[payloadOffset + 2] == 0x01) {
    int ptsDtsFlags = (packet[payloadOffset + 7] & 0xC0) >> 6;
    if (ptsDtsFlags >= 2) {
      int base = payloadOffset + 9;
      int pts = 0;
      pts |= (packet[base] & 0x0E) << 29;
      pts |= (packet[base + 1]) << 22;
      pts |= (packet[base + 2] & 0xFE) << 14;
      pts |= (packet[base + 3]) << 7;
      pts |= (packet[base + 4] & 0xFE) >> 1;
      return pts;
    }
  }
  return null;
}
