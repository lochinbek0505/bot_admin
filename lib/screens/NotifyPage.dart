// notify_page.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sizning mavjud API client faylingiz:
import '../core/api_client.dart';

enum AudienceMode { all, role, tgId }
enum MsgType { text, photo, video, audio, document, mixed }

class NotifyPage extends StatefulWidget {
  /// (ixtiyoriy) Agar siz ApiClient ni tashqarida yaratsangiz, shu yerga bering.
  /// Masalan:
  /// final api = await ApiClient.create();
  /// Navigator.push(context, MaterialPageRoute(builder: (_) => NotifyPage(api: api)));
  final ApiClient? api;

  const NotifyPage({super.key, this.api});

  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  // ── Pref keys
  static const _kAudienceMode = 'audience_mode';
  static const _kAudienceRole = 'audience_role';
  static const _kAudienceTgId = 'audience_tg_id';
  static const _kIncludeBlocked = 'include_blocked';
  static const _kMsgType = 'msg_type';

  // ── State: Audience
  AudienceMode _audienceMode = AudienceMode.all;
  String? _audienceRole; // 'admin' | 'teacher' | 'user'
  final TextEditingController _tgIdCtrl = TextEditingController();
  bool _includeBlocked = false;

  // ── State: Message type
  MsgType _msgType = MsgType.text;

  // ── Text (single) + Mixed text
  final TextEditingController _textCtrl = TextEditingController();
  bool _textHtmlParse = true; // for single text
  bool _textNoPreview = false; // for single text
  bool _textSilent = false; // for single text

  // ── Photo (upload or URL)
  final TextEditingController _photoUrlCtrl = TextEditingController();
  final TextEditingController _photoCaptionCtrl = TextEditingController();
  bool _photoHtmlParse = true;
  bool _photoSilent = false;
  String? _photoUrlError;

  // ── Video (upload)
  PlatformFile? _videoFile;
  String? _videoFileError;
  final TextEditingController _videoCaptionCtrl = TextEditingController();
  bool _videoHtmlParse = true;
  bool _videoSilent = false;

  // ── Audio / Voice (upload)
  PlatformFile? _audioFile;
  String? _audioFileError;
  final TextEditingController _audioCaptionCtrl = TextEditingController();
  bool _audioAsVoice = false;
  bool _audioHtmlParse = true;
  bool _audioSilent = false;

  // ── Document (URL)
  final TextEditingController _docUrlCtrl = TextEditingController();
  final TextEditingController _docCaptionCtrl = TextEditingController();
  bool _docHtmlParse = true;
  bool _docSilent = false;
  String? _docUrlError;

  // ── Mixed
  bool _mixedHtmlParse = true;
  bool _mixedNoPreview = false;
  bool _mixedSilent = false;
  final TextEditingController _mixedCaptionCtrl = TextEditingController();

  // Photos/Documents (URL lists) + photos upload
  final TextEditingController _mixedPhotoUrlCtrl = TextEditingController();
  final TextEditingController _mixedDocUrlCtrl = TextEditingController();
  final List<String> _mixedPhotos = [];
  final List<String> _mixedDocuments = [];

  // Videos/Audios/Voices (upload -> url lists)
  final List<String> _mixedVideos = [];
  final List<String> _mixedAudios = [];
  final List<String> _mixedVoices = [];

  int _pendingUploads = 0;

  // UI/flow
  bool _isSending = false;
  String? _audienceError;
  String? _textError;
  String? _mixedError;

  @override
  void initState() {
    super.initState();
    _restorePrefs();
  }

  @override
  void dispose() {
    _tgIdCtrl.dispose();
    _textCtrl.dispose();
    _photoUrlCtrl.dispose();
    _photoCaptionCtrl.dispose();
    _videoCaptionCtrl.dispose();
    _audioCaptionCtrl.dispose();
    _docUrlCtrl.dispose();
    _docCaptionCtrl.dispose();
    _mixedCaptionCtrl.dispose();
    _mixedPhotoUrlCtrl.dispose();
    _mixedDocUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _restorePrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _audienceMode = AudienceMode.values[
      sp.getInt(_kAudienceMode) ?? AudienceMode.all.index];
      _audienceRole = sp.getString(_kAudienceRole);
      _tgIdCtrl.text = sp.getString(_kAudienceTgId) ?? '';
      _includeBlocked = sp.getBool(_kIncludeBlocked) ?? false;
      _msgType = MsgType.values[sp.getInt(_kMsgType) ?? MsgType.text.index];
    });
  }

  Future<void> _persistAudience() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kAudienceMode, _audienceMode.index);
    if (_audienceRole != null) {
      await sp.setString(_kAudienceRole, _audienceRole!);
    }
    await sp.setString(_kAudienceTgId, _tgIdCtrl.text.trim());
    await sp.setBool(_kIncludeBlocked, _includeBlocked);
  }

  Future<void> _persistMsgType() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kMsgType, _msgType.index);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast')),
      body: AbsorbPointer(
        absorbing: _isSending,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _audienceCard(theme),
              const SizedBox(height: 12),
              _messageTypeCard(),
              const SizedBox(height: 12),
              if (_msgType == MsgType.text) _buildTextSection(theme),
              if (_msgType == MsgType.photo) _buildPhotoSection(theme),
              if (_msgType == MsgType.video) _buildVideoSection(theme),
              if (_msgType == MsgType.audio) _buildAudioSection(theme),
              if (_msgType == MsgType.document) _buildDocumentSection(theme),
              if (_msgType == MsgType.mixed) _buildMixedSection(theme),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: _isSending || _pendingUploads > 0
                      ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending
                        ? 'Sending…'
                        : _pendingUploads > 0
                        ? 'Uploading ($_pendingUploads)…'
                        : 'Send',
                  ),
                  onPressed: (_isSending || _pendingUploads > 0)
                      ? null
                      : _onSendPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Audience card
  Widget _audienceCard(ThemeData theme) {
    return _card(
      title: 'Audience',
      child: Column(
        children: [
          RadioListTile<AudienceMode>(
            title: const Text('All users'),
            value: AudienceMode.all,
            groupValue: _audienceMode,
            onChanged: (v) {
              setState(() {
                _audienceMode = v!;
                _audienceError = null;
              });
              _persistAudience();
            },
          ),
          RadioListTile<AudienceMode>(
            title: Row(
              children: [
                const Text('By role'),
                const SizedBox(width: 12),
                Expanded(
                  child: IgnorePointer(
                    ignoring: _audienceMode != AudienceMode.role,
                    child: Opacity(
                      opacity: _audienceMode == AudienceMode.role ? 1 : .5,
                      child: DropdownButtonFormField<String>(
                        value: _audienceRole,
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('admin')),
                          DropdownMenuItem(value: 'teacher', child: Text('teacher')),
                          DropdownMenuItem(value: 'user', child: Text('user')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _audienceRole = v;
                            _audienceError = null;
                          });
                          _persistAudience();
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'select role',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            value: AudienceMode.role,
            groupValue: _audienceMode,
            onChanged: (v) {
              setState(() {
                _audienceMode = v!;
                _audienceError = null;
              });
              _persistAudience();
            },
          ),
          RadioListTile<AudienceMode>(
            title: Row(
              children: [
                const Text('By tg_id'),
                const SizedBox(width: 12),
                Expanded(
                  child: IgnorePointer(
                    ignoring: _audienceMode != AudienceMode.tgId,
                    child: Opacity(
                      opacity: _audienceMode == AudienceMode.tgId ? 1 : .5,
                      child: TextField(
                        controller: _tgIdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'e.g. 1310448120',
                        ),
                        onChanged: (_) {
                          _audienceError = null;
                          _persistAudience();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            value: AudienceMode.tgId,
            groupValue: _audienceMode,
            onChanged: (v) {
              setState(() {
                _audienceMode = v!;
                _audienceError = null;
              });
              _persistAudience();
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            title: const Text('Include blocked'),
            value: _includeBlocked,
            onChanged: (v) {
              setState(() => _includeBlocked = v);
              _persistAudience();
            },
          ),
          if (_audienceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _audienceError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageTypeCard() {
    return _card(
      title: 'Message type',
      child: Wrap(
        spacing: 8,
        children: [
          _chip(MsgType.text, 'Text'),
          _chip(MsgType.photo, 'Photo'),
          _chip(MsgType.video, 'Video'),
          _chip(MsgType.audio, 'Audio/Voice'),
          _chip(MsgType.document, 'Document'),
          _chip(MsgType.mixed, 'Mixed'),
        ],
      ),
    );
  }

  Widget _chip(MsgType t, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _msgType == t,
      onSelected: (_) {
        setState(() => _msgType = t);
        _persistMsgType();
      },
    );
  }

  // ── Sections
  Widget _buildTextSection(ThemeData theme) {
    return _card(
      title: 'Text message',
      child: Column(
        children: [
          TextField(
            controller: _textCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Write your message…',
              errorText: _textError,
            ),
            onChanged: (_) => setState(() => _textError = null),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('HTML parse_mode'),
                  value: _textHtmlParse,
                  onChanged: (v) =>
                      setState(() => _textHtmlParse = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Disable link preview'),
                  value: _textNoPreview,
                  onChanged: (v) =>
                      setState(() => _textNoPreview = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Silent'),
                  value: _textSilent,
                  onChanged: (v) => setState(() => _textSilent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(ThemeData theme) {
    return _card(
      title: 'Photo (URL yoki fayldan)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _pickAndUploadPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pick photo'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _photoUrlCtrl.text.isEmpty
                      ? 'No uploaded photo yet'
                      : _photoUrlCtrl.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _photoUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Photo URL (e.g. /static/images/pic.jpg)',
              isDense: true,
              errorText: _photoUrlError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _photoCaptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              isDense: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('HTML parse_mode'),
                  value: _photoHtmlParse,
                  onChanged: (v) =>
                      setState(() => _photoHtmlParse = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Silent'),
                  value: _photoSilent,
                  onChanged: (v) =>
                      setState(() => _photoSilent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(ThemeData theme) {
    return _card(
      title: 'Video',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pickRow(
            label: 'Select video',
            onPick: _pickVideo,
            file: _videoFile,
            exts: const ['mp4', 'mov', 'm4v'],
          ),
          if (_videoFileError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _videoFileError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _videoCaptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              isDense: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('HTML parse_mode'),
                  value: _videoHtmlParse,
                  onChanged: (v) =>
                      setState(() => _videoHtmlParse = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Silent'),
                  value: _videoSilent,
                  onChanged: (v) =>
                      setState(() => _videoSilent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSection(ThemeData theme) {
    return _card(
      title: 'Audio / Voice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pickRow(
            label: 'Select audio',
            onPick: _pickAudio,
            file: _audioFile,
            exts: const ['mp3', 'm4a', 'ogg', 'wav'],
          ),
          if (_audioFileError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _audioFileError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _audioCaptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            dense: true,
            title: const Text('Send as voice'),
            value: _audioAsVoice,
            onChanged: (v) => setState(() => _audioAsVoice = v),
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('HTML parse_mode'),
                  value: _audioHtmlParse,
                  onChanged: (v) =>
                      setState(() => _audioHtmlParse = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Silent'),
                  value: _audioSilent,
                  onChanged: (v) =>
                      setState(() => _audioSilent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(ThemeData theme) {
    return _card(
      title: 'Document (URL)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _docUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Document URL (e.g. /static/pdfs/file.pdf)',
              isDense: true,
              errorText: _docUrlError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _docCaptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              isDense: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('HTML parse_mode'),
                  value: _docHtmlParse,
                  onChanged: (v) =>
                      setState(() => _docHtmlParse = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Silent'),
                  value: _docSilent,
                  onChanged: (v) =>
                      setState(() => _docSilent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMixedSection(ThemeData theme) {
    return _card(
      title: 'Mixed (text + medias)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text (optional)
          TextField(
            controller: _textCtrl,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Text (optional)',
              hintText: 'Write a message…',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('HTML parse_mode'),
                  value: _mixedHtmlParse,
                  onChanged: (v) =>
                      setState(() => _mixedHtmlParse = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Disable link preview'),
                  value: _mixedNoPreview,
                  onChanged: (v) =>
                      setState(() => _mixedNoPreview = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Silent'),
                  value: _mixedSilent,
                  onChanged: (v) =>
                      setState(() => _mixedSilent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mixedCaptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption for ALL medias (optional)',
              isDense: true,
            ),
          ),
          const Divider(height: 24),

          // Photos (UPLOAD from gallery)
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _pickMixedPhotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Add photos'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _mixedPhotos.isEmpty
                      ? 'No photos yet'
                      : '${_mixedPhotos.length} photo(s)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Photos (also add by URL)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mixedPhotoUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Add photo URL',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  final u = _mixedPhotoUrlCtrl.text.trim();
                  if (u.isEmpty) return;
                  setState(() {
                    _mixedPhotos.add(u);
                    _mixedPhotoUrlCtrl.clear();
                  });
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _chips('Photos', _mixedPhotos, (i) {
            setState(() => _mixedPhotos.removeAt(i));
          }),

          const SizedBox(height: 12),

          // Videos (upload)
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _pickMixedVideos,
                icon: const Icon(Icons.movie_creation_outlined),
                label: const Text('Add videos'),
              ),
              const SizedBox(width: 12),
              if (_pendingUploads > 0)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _chips('Videos', _mixedVideos, (i) {
            setState(() => _mixedVideos.removeAt(i));
          }),

          const SizedBox(height: 12),

          // Audios (upload)
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _pickMixedAudios,
                icon: const Icon(Icons.audiotrack_outlined),
                label: const Text('Add audios'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _pickMixedVoices,
                icon: const Icon(Icons.mic_none),
                label: const Text('Add voices'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _chips('Audios', _mixedAudios, (i) {
            setState(() => _mixedAudios.removeAt(i));
          }),
          const SizedBox(height: 6),
          _chips('Voices', _mixedVoices, (i) {
            setState(() => _mixedVoices.removeAt(i));
          }),

          const SizedBox(height: 12),

          // Documents (URL add)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mixedDocUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Add document URL',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  final u = _mixedDocUrlCtrl.text.trim();
                  if (u.isEmpty) return;
                  setState(() {
                    _mixedDocuments.add(u);
                    _mixedDocUrlCtrl.clear();
                  });
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _chips('Documents', _mixedDocuments, (i) {
            setState(() => _mixedDocuments.removeAt(i));
          }),

          if (_mixedError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _mixedError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ── Chips helper
  Widget _chips(String label, List<String> items, void Function(int) onRemove) {
    if (items.isEmpty) {
      return Text('$label: (empty)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12));
    }
    return Wrap(
      spacing: 8,
      runSpacing: -6,
      children: [
        for (int i = 0; i < items.length; i++)
          Chip(
            label: Text(items[i], overflow: TextOverflow.ellipsis),
            onDeleted: () => onRemove(i),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pickers
  // ──────────────────────────────────────────────────────────────────────────
  Widget _pickRow({
    required String label,
    required Future<void> Function() onPick,
    required List<String> exts,
    PlatformFile? file,
  }) {
    return Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: onPick,
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(label),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            file == null
                ? 'No file selected'
                : '${file.name} — ${_formatBytes(file.size)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _pickVideo() async {
    setState(() {
      _videoFileError = null;
      _videoFile = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'm4v'],
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _videoFile = result.files.first);
    }
  }

  Future<void> _pickAudio() async {
    setState(() {
      _audioFileError = null;
      _audioFile = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'ogg', 'wav'],
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _audioFile = result.files.first);
    }
  }

  // PHOTO — single: pick & upload, set into _photoUrlCtrl
  Future<void> _pickAndUploadPhoto() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) return;
      setState(() => _pendingUploads++);

      final api = await _getApi();
      final url = await uploadImageFile(api, picked.files.first);
      setState(() {
        _photoUrlCtrl.text = url;
        _photoUrlError = null;
      });
      _showSnack('Photo uploaded.');
    } catch (e) {
      _showSnack('Photo upload failed: $e', error: true);
    } finally {
      setState(() => _pendingUploads = (_pendingUploads - (picked?.files.length ?? 1)).clamp(0, 1 << 20));
    }
  }

  // PHOTO — mixed: multiple pick & upload, push into _mixedPhotos
  Future<void> _pickMixedPhotos() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) return;
      setState(() => _pendingUploads += picked!.files.length);

      final api = await _getApi();
      for (final f in picked.files) {
        final url = await uploadImageFile(api, f);
        setState(() => _mixedPhotos.add(url));
      }
      _showSnack('Photos uploaded.');
    } catch (e) {
      _showSnack('Photo upload failed: $e', error: true);
    } finally {
      setState(() => _pendingUploads = (_pendingUploads - (picked?.files.length ?? 1)).clamp(0, 1 << 20));
    }
  }

  // Mixed videos
  Future<void> _pickMixedVideos() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mov', 'm4v'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() => _pendingUploads += result!.files.length);
      final api = await _getApi();
      for (final f in result.files) {
        final url = await uploadVideoFile(api, f);
        setState(() => _mixedVideos.add(url));
      }
      _showSnack('Videos uploaded.');
    } catch (e) {
      _showSnack('Video upload failed: $e', error: true);
    } finally {
      setState(() => _pendingUploads = (_pendingUploads - (result?.files.length ?? 1)).clamp(0, 1 << 20));
    }
  }

  // Mixed audios
  Future<void> _pickMixedAudios() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'ogg', 'wav'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() => _pendingUploads += result!.files.length);
      final api = await _getApi();
      for (final f in result.files) {
        final url = await uploadAudioFile(api, f);
        setState(() => _mixedAudios.add(url));
      }
      _showSnack('Audios uploaded.');
    } catch (e) {
      _showSnack('Audio upload failed: $e', error: true);
    } finally {
      setState(() => _pendingUploads = (_pendingUploads - (result?.files.length ?? 1)).clamp(0, 1 << 20));
    }
  }

  // Mixed voices (same upload as audio; server side you’ll sendVoice later)
  Future<void> _pickMixedVoices() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'ogg', 'wav'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() => _pendingUploads += result!.files.length);
      final api = await _getApi();
      for (final f in result.files) {
        final url = await uploadAudioFile(api, f);
        setState(() => _mixedVoices.add(url));
      }
      _showSnack('Voices uploaded.');
    } catch (e) {
      _showSnack('Voice upload failed: $e', error: true);
    } finally {
      setState(() => _pendingUploads = (_pendingUploads - (result?.files.length ?? 1)).clamp(0, 1 << 20));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SEND
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _onSendPressed() async {
    // Validate audience
    final audOk = _validateAudience();
    if (!audOk) {
      _showSnack('Please fix audience selection.', error: true);
      return;
    }

    // Validate by type
    if (_msgType == MsgType.text) {
      if (_textCtrl.text.trim().isEmpty) {
        setState(() => _textError = 'Text cannot be empty');
        _showSnack('Message text is required.', error: true);
        return;
      }
    } else if (_msgType == MsgType.photo) {
      if (_photoUrlCtrl.text.trim().isEmpty) {
        setState(() => _photoUrlError = 'Photo URL is required');
        _showSnack('Photo URL is required.', error: true);
        return;
      }
    } else if (_msgType == MsgType.video) {
      if (_videoFile == null) {
        setState(() => _videoFileError = 'Please select a video file');
        _showSnack('Video file is required.', error: true);
        return;
      }
    } else if (_msgType == MsgType.audio) {
      if (_audioFile == null) {
        setState(() => _audioFileError = 'Please select an audio file');
        _showSnack('Audio file is required.', error: true);
        return;
      }
    } else if (_msgType == MsgType.document) {
      if (_docUrlCtrl.text.trim().isEmpty) {
        setState(() => _docUrlError = 'Document URL is required');
        _showSnack('Document URL is required.', error: true);
        return;
      }
    } else if (_msgType == MsgType.mixed) {
      final hasAnything = _textCtrl.text.trim().isNotEmpty ||
          _mixedPhotos.isNotEmpty ||
          _mixedVideos.isNotEmpty ||
          _mixedAudios.isNotEmpty ||
          _mixedVoices.isNotEmpty ||
          _mixedDocuments.isNotEmpty;
      if (!hasAnything) {
        setState(() => _mixedError = 'Add text or at least one media.');
        _showSnack('Mixed: nothing to send.', error: true);
        return;
      } else {
        setState(() => _mixedError = null);
      }
    }

    setState(() => _isSending = true);
    try {
      final api = await _getApi();
      Map<String, dynamic> resp;

      switch (_msgType) {
        case MsgType.text: {
          final form = await _buildAudienceMap();
          form['text'] = _textCtrl.text.trim();
          form['include_blocked'] = _includeBlocked;
          form['disable_notification'] = _textSilent;
          form['to_all'] ??= _audienceMode == AudienceMode.all;
          if (_textHtmlParse) form['parse_mode'] = 'HTML';
          form['disable_web_page_preview'] = _textNoPreview;
          resp = await api.notifyText(form);
          break;
        }
        case MsgType.photo: {
          final form = await _buildAudienceMap();
          form['media_url'] = _photoUrlCtrl.text.trim();
          final cap = _photoCaptionCtrl.text.trim();
          if (cap.isNotEmpty) form['caption'] = cap;
          if (_photoHtmlParse) form['parse_mode'] = 'HTML';
          form['include_blocked'] = _includeBlocked;
          form['disable_notification'] = _photoSilent;
          resp = await api.notifyPhoto(form);
          break;
        }
        case MsgType.video: {
          // upload first
          final url = await uploadVideoFile(api, _videoFile!);
          final form = await _buildAudienceMap();
          form['media_url'] = url;
          final cap = _videoCaptionCtrl.text.trim();
          if (cap.isNotEmpty) form['caption'] = cap;
          if (_videoHtmlParse) form['parse_mode'] = 'HTML';
          form['include_blocked'] = _includeBlocked;
          form['disable_notification'] = _videoSilent;
          resp = await api.notifyVideo(form);
          break;
        }
        case MsgType.audio: {
          // upload first
          final url = await uploadAudioFile(api, _audioFile!);
          final form = await _buildAudienceMap();
          form['media_url'] = url;
          final cap = _audioCaptionCtrl.text.trim();
          if (cap.isNotEmpty) form['caption'] = cap;
          form['as_voice'] = _audioAsVoice;
          if (_audioHtmlParse) form['parse_mode'] = 'HTML';
          form['include_blocked'] = _includeBlocked;
          form['disable_notification'] = _audioSilent;
          resp = await api.notifyAudio(form);
          break;
        }
        case MsgType.document: {
          final form = await _buildAudienceMap();
          form['media_url'] = _docUrlCtrl.text.trim();
          final cap = _docCaptionCtrl.text.trim();
          if (cap.isNotEmpty) form['caption'] = cap;
          if (_docHtmlParse) form['parse_mode'] = 'HTML';
          form['include_blocked'] = _includeBlocked;
          form['disable_notification'] = _docSilent;
          resp = await api.notifyDocument(form);
          break;
        }
        case MsgType.mixed: {
          // Build FormData manually to repeat list keys
          final form = FormData();
          // Audience + flags
          final aud = await _buildAudienceMap();
          _fdAdd(form, 'include_blocked', _includeBlocked);
          _fdMaybe(form, 'tg_id', aud['tg_id']);
          _fdMaybe(form, 'role', aud['role']);
          _fdAdd(form, 'to_all', (aud['to_all'] == true));

          // Text (optional)
          final txt = _textCtrl.text.trim();
          if (txt.isNotEmpty) {
            _fdAdd(form, 'text', txt);
            if (_mixedHtmlParse) _fdAdd(form, 'parse_mode', 'HTML');
            _fdAdd(form, 'disable_web_page_preview', _mixedNoPreview);
          }
          // Caption (optional) for all medias
          final cap = _mixedCaptionCtrl.text.trim();
          if (cap.isNotEmpty) _fdAdd(form, 'caption', cap);

          // Lists (photos, videos, audios, voices, documents)
          for (final u in _mixedPhotos) {
            form.fields.add(MapEntry('photos', u));
          }
          for (final u in _mixedVideos) {
            form.fields.add(MapEntry('videos', u));
          }
          for (final u in _mixedAudios) {
            form.fields.add(MapEntry('audios', u));
          }
          for (final u in _mixedVoices) {
            form.fields.add(MapEntry('voices', u));
          }
          for (final u in _mixedDocuments) {
            form.fields.add(MapEntry('documents', u));
          }

          _fdAdd(form, 'disable_notification', _mixedSilent);
          resp = await api.notifyMixed(form);
          break;
        }
      }

      final scheduled = resp['scheduled'];
      if (scheduled is int) {
        _showSnack('Scheduled for $scheduled users.');
      } else {
        _showSnack('Broadcast scheduled.');
      }
    } on DioException catch (e) {
      final msg = _extractDioError(e);
      _showSnack(msg, error: true);
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Audience helpers
  // ──────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _buildAudienceMap() async {
    final map = <String, dynamic>{};
    switch (_audienceMode) {
      case AudienceMode.all:
        map['to_all'] = true;
        break;
      case AudienceMode.role:
        map['role'] = _audienceRole;
        map['to_all'] = false;
        break;
      case AudienceMode.tgId:
        final id = int.tryParse(_tgIdCtrl.text.trim());
        map['tg_id'] = id;
        map['to_all'] = false;
        break;
    }
    return map;
  }

  bool _validateAudience() {
    String? err;
    switch (_audienceMode) {
      case AudienceMode.all:
        err = null;
        break;
      case AudienceMode.role:
        if (_audienceRole == null || _audienceRole!.isEmpty) {
          err = 'Please select a role';
        }
        break;
      case AudienceMode.tgId:
        final id = int.tryParse(_tgIdCtrl.text.trim());
        if (id == null) {
          err = 'tg_id must be a valid integer';
        }
        break;
    }
    setState(() => _audienceError = err);
    return err == null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Utils
  // ──────────────────────────────────────────────────────────────────────────
  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor().clamp(0, units.length - 1);
    final v = bytes / (1 << (10 * i));
    return '${v.toStringAsFixed(1)} ${units[i]}';
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<ApiClient> _getApi() async {
    if (widget.api != null) return widget.api!;
    // Agar sizda factory bo'lsa: NotifyPage(api: await ApiClient.create()) deb bering.
    return ApiClient(baseUrl: 'http://185.217.131.39',apiKey:"changeme" );  }

  void _fdMaybe(FormData f, String k, Object? v) {
    if (v == null) return;
    f.fields.add(MapEntry(k, v.toString()));
  }

  void _fdAdd(FormData f, String k, Object v) {
    f.fields.add(MapEntry(k, v.toString()));
  }
}

// ────────────────────────────────────────────────────────────────────────────
// API helpers (uploads)
// ────────────────────────────────────────────────────────────────────────────

/// Upload image; returns `/static/images/...` URL
Future<String> uploadImageFile(ApiClient api, PlatformFile f) async {
  final mf = await _toMultipart(f);
  final form = FormData.fromMap({'file': mf});
  final res = await api.dio.post('/upload/image', data: form);
  final data = res.data is Map ? res.data as Map : <String, dynamic>{};
  final url = data['url']?.toString();
  if (url == null || url.isEmpty) {
    throw Exception('Upload failed: no url returned');
  }
  return url;
}

/// Upload audio; returns `/static/audios/...` URL
Future<String> uploadAudioFile(ApiClient api, PlatformFile f) async {
  final mf = await _toMultipart(f);
  final res = await api.dio.post('/upload/audio', data: FormData.fromMap({'file': mf}));
  final data = res.data is Map ? res.data as Map : <String, dynamic>{};
  final url = data['url']?.toString();
  if (url == null || url.isEmpty) {
    throw Exception('Upload failed: no url returned');
  }
  return url;
}

/// Upload video; returns `/static/videos/...` URL
Future<String> uploadVideoFile(ApiClient api, PlatformFile f) async {
  final mf = await _toMultipart(f);
  final res = await api.dio.post('/upload/video', data: FormData.fromMap({'file': mf}));
  final data = res.data is Map ? res.data as Map : <String, dynamic>{};
  final url = data['url']?.toString();
  if (url == null || url.isEmpty) {
    throw Exception('Upload failed: no url returned');
  }
  return url;
}

Future<MultipartFile> _toMultipart(PlatformFile f) async {
  if (kIsWeb || f.bytes != null) {
    final Uint8List bytes = f.bytes!;
    return MultipartFile.fromBytes(bytes, filename: f.name);
  }
  if (f.path != null && f.path!.isNotEmpty) {
    return MultipartFile.fromFile(f.path!, filename: f.name);
  }
  throw Exception('Invalid file: no bytes or path');
}

// ────────────────────────────────────────────────────────────────────────────
// ApiClient extensions — yangi endpointlar
// ────────────────────────────────────────────────────────────────────────────
extension NotifyApi on ApiClient {
  Future<Map<String, dynamic>> notifyText(Map<String, dynamic> form) async {
    final res = await dio.post('/notify/text', data: FormData.fromMap(form));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> notifyPhoto(Map<String, dynamic> form) async {
    final res = await dio.post('/notify/photo', data: FormData.fromMap(form));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> notifyVideo(Map<String, dynamic> form) async {
    final res = await dio.post('/notify/video', data: FormData.fromMap(form));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> notifyAudio(Map<String, dynamic> form) async {
    final res = await dio.post('/notify/audio', data: FormData.fromMap(form));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> notifyDocument(Map<String, dynamic> form) async {
    final res = await dio.post('/notify/document', data: FormData.fromMap(form));
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Mixed uchun takroriy list fieldlar kerak — FormData ni to'g'ridan-to'g'ri qabul qilamiz.
  Future<Map<String, dynamic>> notifyMixed(FormData form) async {
    final res = await dio.post('/notify/mixed', data: form);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> stats() async {
    final res = await dio.get('/stats');
    return Map<String, dynamic>.from(res.data as Map);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Error helper
// ────────────────────────────────────────────────────────────────────────────
String _extractDioError(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return 'Error: ${data['detail']}';
    }
    if (data is String && data.isNotEmpty) {
      return 'Error: $data';
    }
  } catch (_) {}
  return 'Network error: ${e.message ?? e.toString()}';
}
