// KENOS — POC « FRÉQUENCES » (Symphonie Collective) — référence design
// soumise par Hugo avec le manifeste V2 (archivé verbatim).
//
// NOTE: this React/Tailwind chart is NOT the Cosmic Zen identity (see
// ../portfolio-os/PROJECT_DESIGN_REGISTRY.md) and is never imported
// into the app. What this POC pins is the MECHANICS: 20-note major
// pentatonic scale (any combination is consonant), Y = pitch register
// (low = heavy/melancholy, high = light/hope), X = timbre + hue, slow
// ADSR nebula envelopes, a compressor before the master out, and a
// ~10 s wave lifetime. The Flutter port specs live in
// ../docs/ROADMAP_V3.md; the Cosmic Zen styling is derived there.
//
// A build-free HTML port of these mechanics (testable on a phone):
// poc/frequencies.html.

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Activity, Wind, Sparkles, Radio } from 'lucide-react';

export default function App() {
  const [nodes, setNodes] = useState([]);
  const [isActive, setIsActive] = useState(false);
  
  // Audio Refs
  const audioCtxRef = useRef(null);
  const masterGainRef = useRef(null);
  
  // Gamme Pentatonique Majeure (C, D, E, G, A) sur plusieurs octaves
  // Garantit que toutes les notes jouées ensemble seront harmonieuses
  const scale = [
    65.41, 73.42, 82.41, 98.00, 110.00, // C2 - A2 (Graves/Mélancolie)
    130.81, 146.83, 164.81, 196.00, 220.00, // C3 - A3 (Neutre/Calme)
    261.63, 293.66, 329.63, 392.00, 440.00, // C4 - A4 (Clair/Espoir)
    523.25, 587.33, 659.25, 783.99, 880.00  // C5 - A5 (Cristallin/Joie)
  ];

  const initAudio = () => {
    if (audioCtxRef.current) return;
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    const ctx = new AudioContext();
    const masterGain = ctx.createGain();
    
    // Compresseur pour éviter la saturation si trop de notes
    const compressor = ctx.createDynamicsCompressor();
    compressor.threshold.setValueAtTime(-24, ctx.currentTime);
    compressor.knee.setValueAtTime(30, ctx.currentTime);
    compressor.ratio.setValueAtTime(12, ctx.currentTime);
    compressor.attack.setValueAtTime(0.003, ctx.currentTime);
    compressor.release.setValueAtTime(0.25, ctx.currentTime);

    masterGain.connect(compressor);
    compressor.connect(ctx.destination);
    masterGain.gain.value = 0.5;

    audioCtxRef.current = ctx;
    masterGainRef.current = masterGain;
    setIsActive(true);
  };

  const mapYToFrequency = (y, height) => {
    // Y inversé : Bas de l'écran = Grave (triste), Haut de l'écran = Aigu (joie)
    const normalizedY = 1 - (y / height);
    const index = Math.floor(normalizedY * scale.length);
    return scale[Math.min(Math.max(index, 0), scale.length - 1)];
  };

  const mapXToColor = (x, width) => {
    const normalizedX = x / width;
    if (normalizedX < 0.25) return 'bg-purple-600 shadow-purple-500/50';
    if (normalizedX < 0.5) return 'bg-indigo-500 shadow-indigo-400/50';
    if (normalizedX < 0.75) return 'bg-teal-400 shadow-teal-300/50';
    return 'bg-rose-400 shadow-rose-300/50';
  };

  const playGenerativeNode = useCallback((x, y, width, height) => {
    initAudio();
    const ctx = audioCtxRef.current;
    if (!ctx) return;

    const freq = mapYToFrequency(y, height);
    const color = mapXToColor(x, width);
    const id = Date.now();

    // --- SYNTHÈSE SONORE ---
    const osc = ctx.createOscillator();
    const gainNode = ctx.createGain();
    
    // Type d'onde selon la position X (gauche = doux, droite = plus brillant)
    osc.type = (x / width) > 0.5 ? 'triangle' : 'sine';
    osc.frequency.setValueAtTime(freq, ctx.currentTime);

    // Enveloppe ADSR (Attack, Decay, Sustain, Release) très lente pour le côté "Nébuleuse"
    const attackTime = 2.0;
    const sustainTime = 4.0;
    const releaseTime = 4.0;
    const maxVol = 0.15;

    gainNode.gain.setValueAtTime(0, ctx.currentTime);
    // Attack
    gainNode.gain.linearRampToValueAtTime(maxVol, ctx.currentTime + attackTime);
    // Sustain -> Release
    gainNode.gain.setTargetAtTime(0, ctx.currentTime + attackTime + sustainTime, releaseTime / 3);

    osc.connect(gainNode);
    gainNode.connect(masterGainRef.current);
    
    osc.start();
    // Arrêt complet du nœud après la fin du release
    osc.stop(ctx.currentTime + attackTime + sustainTime + releaseTime + 1);

    // --- MISE À JOUR UI ---
    const newNode = { id, x, y, color, active: true };
    setNodes(prev => [...prev, newNode]);

    // Cleanup visuel synchronisé avec l'audio (10 secondes de vie totale)
    setTimeout(() => {
      setNodes(prev => prev.map(n => n.id === id ? { ...n, active: false } : n));
      setTimeout(() => {
        setNodes(prev => prev.filter(n => n.id !== id));
      }, 2000); // Temps du fondu visuel
    }, (attackTime + sustainTime + releaseTime) * 1000);

  }, []);

  const handleInteraction = (e) => {
    let clientX, clientY;
    if (e.touches) {
      clientX = e.touches[0].clientX;
      clientY = e.touches[0].clientY;
    } else {
      clientX = e.clientX;
      clientY = e.clientY;
    }
    
    const rect = e.currentTarget.getBoundingClientRect();
    const x = clientX - rect.left;
    const y = clientY - rect.top;
    
    playGenerativeNode(x, y, rect.width, rect.height);
  };

  return (
    <div className="h-screen w-full bg-[#020305] text-white flex flex-col font-sans overflow-hidden select-none">
      
      {/* HEADER */}
      <header className="w-full px-6 py-4 flex justify-between items-center z-20 bg-[#020305]/80 backdrop-blur-md border-b border-white/5">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 flex items-center justify-center bg-black border border-indigo-500/50 rounded-lg shadow-[0_0_15px_rgba(99,102,241,0.2)]">
            <Radio size={16} className="text-indigo-400 animate-pulse" />
          </div>
          <div>
            <h1 className="text-sm font-bold tracking-[0.2em]">FRÉQUENCES</h1>
            <p className="text-[8px] font-mono uppercase tracking-widest text-indigo-500/70">Générateur Symbiotique</p>
          </div>
        </div>
        <div className="text-[9px] font-mono text-neutral-500 uppercase flex flex-col items-end">
          <span>{nodes.length} ONDES ACTIVES</span>
          <span>Symphonie collective en cours</span>
        </div>
      </header>

      {/* ZONE DE RÉSONANCE (CANVAS) */}
      <main 
        className="flex-grow relative cursor-crosshair overflow-hidden"
        onClick={handleInteraction}
      >
        {/* Grilles et Télémétrie visuelle */}
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-1/2 left-0 w-full h-[1px] bg-white/5"></div>
          <div className="absolute top-1/4 left-0 w-full h-[1px] bg-white/5 border-t border-dashed border-white/5"></div>
          <div className="absolute top-3/4 left-0 w-full h-[1px] bg-white/5 border-t border-dashed border-white/5"></div>
          
          <div className="absolute top-4 left-4 text-[8px] font-mono text-neutral-600 uppercase">Aigu / Léger / Espoir</div>
          <div className="absolute bottom-4 left-4 text-[8px] font-mono text-neutral-600 uppercase">Grave / Lourd / Mélancolie</div>
        </div>

        {!isActive && (
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
            <Wind size={32} className="text-white/20 mb-4 animate-pulse" />
            <p className="text-xs font-mono uppercase tracking-widest text-white/40">Touchez l'espace pour émettre une onde</p>
          </div>
        )}

        {/* RENDU DES NÉBULEUSES (ONDES) */}
        {nodes.map(node => (
          <div
            key={node.id}
            className={`absolute rounded-full transition-all duration-[2000ms] ease-out transform -translate-x-1/2 -translate-y-1/2 pointer-events-none ${node.color}`}
            style={{
              left: `${node.x}px`,
              top: `${node.y}px`,
              width: node.active ? '150px' : '0px',
              height: node.active ? '150px' : '0px',
              opacity: node.active ? 0.4 : 0,
              filter: 'blur(30px)',
            }}
          >
            {/* Cœur de l'onde */}
            <div className="absolute inset-0 m-auto w-4 h-4 rounded-full bg-white opacity-80 filter blur-sm"></div>
          </div>
        ))}

      </main>

      {/* INSTRUCTIONS */}
      <footer className="w-full text-center py-4 border-t border-white/5 z-20 bg-[#020305]">
        <p className="text-[9px] font-mono uppercase tracking-[0.2em] text-neutral-500 flex items-center justify-center gap-2">
          <Sparkles size={10} /> Clique à différents endroits pour superposer les accords
        </p>
      </footer>
    </div>
  );
}
