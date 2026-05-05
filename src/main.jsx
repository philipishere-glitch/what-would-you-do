import React, { useEffect, useMemo, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Heart, X, RotateCcw, Flag, Sparkles, Flame, BarChart3 } from 'lucide-react'
import { supabase, isSupabaseConfigured } from './supabaseClient'
import './styles.css'

const fallbackScenarios = [
  { id: 'demo-1', category: 'Work', intensity: 4, title: 'Your manager presents your idea in a meeting as their own. You are in the room.', option_a: 'Call it out immediately', option_b: 'Let it go and raise it later', ai_take: 'Public correction feels satisfying, but private documentation usually protects you better.' },
  { id: 'demo-2', category: 'Dating', intensity: 3, title: 'Someone you are dating suddenly becomes less responsive after a great weekend together.', option_a: 'Call it out directly', option_b: 'Match their energy', ai_take: 'Directness gives clarity; matching energy protects dignity but can turn into a silent game.' },
  { id: 'demo-3', category: 'Money', intensity: 5, title: 'A close friend asks to borrow a significant amount of money and promises to pay it back next month.', option_a: 'Lend it', option_b: 'Say no kindly', ai_take: 'Money tests relationships. A gift-sized amount is safer than a loan-sized resentment.' }
]

function getDeviceId() {
  const key = 'wyd_device_id'
  let id = localStorage.getItem(key)
  if (!id) {
    id = crypto.randomUUID()
    localStorage.setItem(key, id)
  }
  return id
}

function pct(a, b) {
  const total = a + b
  if (!total) return [50, 50]
  return [Math.round((a / total) * 100), Math.round((b / total) * 100)]
}

function App() {
  const [deviceId] = useState(getDeviceId)
  const [cards, setCards] = useState([])
  const [index, setIndex] = useState(0)
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState(null)
  const [results, setResults] = useState(null)
  const [error, setError] = useState('')
  const [drag, setDrag] = useState({ x: 0, startX: 0, active: false })
  const cardRef = useRef(null)

  const current = cards[index]
  const finished = !loading && index >= cards.length

  useEffect(() => { loadCards() }, [])

  async function loadCards() {
    setLoading(true)
    setError('')
    if (!isSupabaseConfigured) {
      setCards(fallbackScenarios)
      setLoading(false)
      return
    }
    const { data, error } = await supabase
      .from('scenario_stats')
      .select('*')
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
      .limit(80)
    if (error) {
      setError(error.message)
      setCards(fallbackScenarios)
    } else {
      const seen = JSON.parse(localStorage.getItem('wyd_seen') || '[]')
      const fresh = (data || []).filter(card => !seen.includes(card.id))
      setCards(fresh.length ? fresh : data || [])
      if (!fresh.length) localStorage.removeItem('wyd_seen')
    }
    setLoading(false)
  }

  async function vote(choice) {
    if (!current || selected) return
    setSelected(choice)
    const nextA = Number(current.votes_a || 0) + (choice === 'A' ? 1 : 0)
    const nextB = Number(current.votes_b || 0) + (choice === 'B' ? 1 : 0)
    setResults({ a: nextA, b: nextB })

    const seen = JSON.parse(localStorage.getItem('wyd_seen') || '[]')
    localStorage.setItem('wyd_seen', JSON.stringify([...new Set([...seen, current.id])]))

    if (isSupabaseConfigured) {
      await supabase.from('votes').upsert({
        scenario_id: current.id,
        device_id: deviceId,
        choice
      }, { onConflict: 'scenario_id,device_id' })
    }
  }

  function nextCard() {
    setSelected(null)
    setResults(null)
    setDrag({ x: 0, startX: 0, active: false })
    setIndex(i => i + 1)
  }

  function rewind() {
    setSelected(null)
    setResults(null)
    setIndex(i => Math.max(0, i - 1))
  }

  function onPointerDown(e) {
    if (selected) return
    setDrag({ x: 0, startX: e.clientX, active: true })
    cardRef.current?.setPointerCapture(e.pointerId)
  }
  function onPointerMove(e) {
    if (!drag.active || selected) return
    setDrag(d => ({ ...d, x: e.clientX - d.startX }))
  }
  function onPointerUp() {
    if (!drag.active || selected) return
    if (drag.x > 90) vote('A')
    else if (drag.x < -90) vote('B')
    else setDrag({ x: 0, startX: 0, active: false })
  }

  const rotate = Math.max(-12, Math.min(12, drag.x / 18))
  const [pa, pb] = results ? pct(results.a, results.b) : [0, 0]

  return <main className="app">
    <section className="phone-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Swipe the dilemma</p>
          <h1>Would You Do?</h1>
        </div>
        <div className="streak"><Flame size={18}/> {index + 1}</div>
      </header>

      {loading && <div className="state">Loading dilemmas…</div>}
      {error && <div className="banner">Supabase issue: {error}. Showing demo cards.</div>}

      {finished && <div className="empty">
        <Sparkles size={42}/>
        <h2>You cleared the feed.</h2>
        <p>Add more scenarios in Supabase, or reset your seen cards.</p>
        <button onClick={() => { localStorage.removeItem('wyd_seen'); setIndex(0); loadCards() }}>Reset feed</button>
      </div>}

      {current && !finished && <>
        <div className="progress"><span style={{ width: `${Math.min(100, ((index + 1) / cards.length) * 100)}%` }} /></div>
        <article
          ref={cardRef}
          className={`card ${selected ? 'answered' : ''}`}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          style={{ transform: `translateX(${selected ? 0 : drag.x}px) rotate(${selected ? 0 : rotate}deg)` }}
        >
          <div className="card-meta">
            <span>{current.category}</span>
            <span>Intensity {current.intensity}/5</span>
          </div>
          <h2>{current.title}</h2>
          {!selected && <p className="hint">Swipe right for A, left for B — or tap below.</p>}

          <div className="choices">
            <button className={selected === 'A' ? 'picked' : ''} onClick={() => vote('A')}>
              <span>A</span>{current.option_a}
            </button>
            <button className={selected === 'B' ? 'picked' : ''} onClick={() => vote('B')}>
              <span>B</span>{current.option_b}
            </button>
          </div>

          {selected && <section className="results">
            <div className="result-row"><b>{current.option_a}</b><em>{pa}%</em></div>
            <div className="meter"><span style={{ width: `${pa}%` }} /></div>
            <div className="result-row"><b>{current.option_b}</b><em>{pb}%</em></div>
            <div className="meter"><span style={{ width: `${pb}%` }} /></div>
            <p className="take"><BarChart3 size={16}/> {current.ai_take}</p>
          </section>}
        </article>

        <nav className="actions">
          <button aria-label="Rewind" onClick={rewind}><RotateCcw /></button>
          <button className="no" onClick={() => vote('B')}><X /></button>
          <button className="yes" onClick={() => vote('A')}><Heart /></button>
          <button aria-label="Report"><Flag /></button>
        </nav>
        {selected && <button className="next" onClick={nextCard}>Next dilemma</button>}
      </>}
    </section>
  </main>
}

createRoot(document.getElementById('root')).render(<App />)
