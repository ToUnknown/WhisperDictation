<div align="center">
  <table>
    <tr>
      <td>
        <img src="docs/assets/Icon.png" style="width: 84px; height: 84px;" alt="Speakly icon" />
      </td>
      <td>
        <div style="font-size: 36px; font-weight: 700; line-height: 1; margin-left: 8px;">Speakly</div>
      </td>
    </tr>
  </table>
</div>

<p align="center">
  You're tired of breaking your flow to type every quick thought, so Speakly lives in your menu bar and turns voice into clean text on demand.
</p>

## Built With

- Swift and SwiftUI for the macOS UI and menu bar experience
- AppKit for menu bar integration and window control
- OpenAI Audio Transcriptions API (model: `gpt-4o-transcribe`)
- AVFoundation + CoreAudio for microphone capture and audio processing
- Accelerate for audio analysis
- Combine for state and reactive updates
- Security (Keychain Services) for storing the API key
- CoreGraphics + ApplicationServices for system-level input and text injection
- ServiceManagement for launch-at-login support
- URLSession for network requests

## What is the 4o Transcribe Model by OpenAI?

GPT-4o Transcribe (sometimes called the 4o Transcribe model) is OpenAI's speech-to-text model powered by GPT-4o. It is designed for accurate transcription and improves word error rate and language recognition compared to the original Whisper models. Speakly uses this model to turn your recorded audio into precise, ready-to-paste text.

## Screens

<table>
  <tr>
    <td width="70%" valign="top">
      <h3>Menu Bar Control</h3>
      <p>
        Check your status at a glance and see whether your API key is ready before you start. The
        history list keeps your last transcriptions close, so you can click any line to copy it
        instantly without hunting for it in another app. You can also pick the active microphone,
        refresh devices if something changes, and jump straight into Settings without leaving your
        current workflow.
      </p>
    </td>
    <td width="30%" align="right">
        <img src="docs/assets/menuBar-view.png" width="400" style="border-radius: 18px;" alt="Speakly menu bar view" />
    </td>
  </tr>
</table>

<br />

<table>
  <tr>
    <td width="70%" valign="top">
      <h3>Settings</h3>
      <p>
        Paste your OpenAI API key, confirm it’s saved, and keep it in one place without leaving
        the app. Toggle translation so your spoken audio can automatically land in your current
        keyboard language, then enable launch at login so Speakly is ready the moment you sit down.
        If you want the onboarding tips again, reset the popovers for a clean slate.
      </p>
    </td>
    <td width="30%" align="right">
        <img src="docs/assets/settings-view.png" width="400" style="border-radius: 14px;" alt="Speakly settings view" />
    </td>
  </tr>
</table>
