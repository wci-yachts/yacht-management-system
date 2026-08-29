# West Coast International — Charter Management System

## Cos'è
Un gestionale per un brokerage di charter/vendita yacht, costruito come applicazione
web a pagina singola (un unico file `index.html`, HTML+CSS+JS senza framework).
Gira sia in modalità "locale" (dati salvati solo nel browser, nessun login) sia in
modalità "multiutente" condivisa via Supabase (login richiesto, dati condivisi tra
più persone).

## Struttura del repository
- `index.html` — l'intera applicazione (un solo file, tutto incluso: HTML, CSS, JS)

## Moduli principali dell'app
- **Dashboard**: promemoria pagamenti in scadenza/scaduti
- **Charter Files**: elenco pratiche, ordinabile, filtrabile, con bollino colorato di stato
- **Scheda pratica** (Charter o Sale — due tipi diversi con campi/logica differenti):
  - Dati generali, ruolo (Retail Broker / Central Agent), stato pratica
  - Finanziari: charter rate/sale price, VAT, APA, delivery fee, commissioni
  - Schedule pagamenti: elenco unificato (pagamenti preimpostati + extra),
    riordinabile via drag-and-drop o frecce, con **logica a cascata** (uno
    scostamento sul Client Deposit si ripercuote sul Client Balance atteso, e
    a cascata sull'APA verso l'owner)
  - Riconciliazione Incoming/Outgoing
  - Checklist allegati, note libere
- **Calendar**: vista mensile (due mesi affiancati) con le pratiche come strisce
  colorate per barca
- **Feedback**: raccolta feedback clienti, collegabile alle pratiche, con
  importazione CSV e sincronizzazione da Supabase (vedi sotto)
- **Statistics**: riepilogo per anno (dedotto dalle ultime 4 cifre del numero pratica)

## Modalità multiutente (Supabase)
In cima allo script ci sono queste costanti da configurare:
```js
const SUPABASE_URL = '...';
const SUPABASE_ANON_KEY = '...'; // chiave pubblica, ok che sia nel codice
```
Se lasciate vuote/placeholder, l'app funziona in modalità locale (comportamento
originale). Se compilate, l'app mostra una schermata di login (email/password
create in Supabase → Authentication → Users) e tutti i dati (pratiche, feedback,
impostazioni) vengono letti/scritti in un'unica riga condivisa nella tabella
`workspace` (colonna `data`, di tipo JSONB — contiene l'intero stato dell'app
serializzato).

Lo schema SQL per questa tabella è in `supabase-workspace-schema.sql`.

**Importante**: la chiave `service_role` di Supabase (usata SOLO per la
sincronizzazione dei feedback, sezione Feedback → Sync) NON viene mai salvata
nella riga condivisa — resta solo nel browser di chi la inserisce. Ogni persona
che vuole usare "Sync from server" deve inserirla nel proprio dispositivo.

## Sistema di feedback clienti
Il form pubblico che i clienti compilano è un **file separato**,
`feedback-form.html`, ospitato come progetto Vercel indipendente (per non far
comparire il dominio aziendale nel link). Scrive direttamente in una tabella
Supabase `feedback` (diversa da `workspace`), usando la chiave `anon` (pubblica).
Lo schema SQL è in `supabase-schema.sql`.

Il gestionale (sezione Feedback → Sync Feedback) legge quella tabella usando la
chiave `service_role` (privata) e importa le nuove risposte, agganciandole
automaticamente alla pratica giusta quando barca e data coincidono.

## Cose da sapere prima di modificare il codice
- Tutti i campi importo/percentuale sono `type="text" inputmode="decimal"`,
  **non** `type="number"` — è una scelta deliberata: i controlli nativi dei
  campi numerici causavano bug di perdita del focus durante la digitazione
  (documentato via test approfonditi). Non tornare a `type="number"` per i
  campi legati a `data-money`.
- La funzione `softRerenderCase()` è il cuore del sistema di "ridisegna senza
  perdere il focus" usato per ogni campo modificabile. Se aggiungi un nuovo
  tipo di campo che deve restare focalizzato dopo un ridisegno, va aggiunto lì
  (cercare i rami `if(f) ... else if(...)`).
- La formattazione automatica a due decimali (blur sui campi `data-money`)
  **non** richiama mai `render()`/`softRerenderCase()` di proposito — farlo
  causava una race condition che perdeva il focus del campo successivo su cui
  l'utente aveva già cliccato. Aggiorna solo `el.value` e lo stato interno.
- I pagamenti (preimpostati + extra) condividono un unico ordine
  (`getUnifiedScheduleRows`), così si possono riordinare liberamente tra loro.

## File in questo repository
- `index.html` — l'applicazione
- `supabase-workspace-schema.sql` — schema per la modalità multiutente (tabella `workspace`)
- `supabase-schema.sql` — schema per la tabella `feedback` (usata da feedback-form.html, in un altro repository)
- `PROJECT_NOTES.md` — questo file
