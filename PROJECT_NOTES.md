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

## Preference List clienti
Stesso schema del feedback: form pubblico **in un repository separato**
(`wci-yachts/preference-list-form`, file `preference-list.html`), ospitato come
progetto Vercel indipendente. Scrive in una tabella Supabase dedicata,
`preference_lists`, usando la chiave `anon` — schema SQL in
`supabase-preference-list-schema.sql`.

Nella scheda di ogni pratica (sezione "Send → Preference List") si imposta una
volta sola l'URL base del form pubblico (salvato condiviso in
`STATE.preferenceListSync.baseUrl`), e i due pulsanti "Copy link" costruiscono
l'URL completo aggiungendo `client=`, `yacht=`, `start=`, `end=` (precompilano
il form) e, per la versione brandizzata, `wci=1`. Lo stesso file
`preference-list.html` serve entrambe le versioni — con o senza `wci=1` mostra
o nasconde loghi/colori West Coast International, letti da `location.search`
al caricamento.

**Sync-back nel gestionale** (a differenza del feedback, aggiunto in seguito):
Feedback → Preferences → "Sync from server" legge la tabella `preference_lists`
riusando le STESSE credenziali già inserite per il Feedback sync (stesso
progetto Supabase, stessa `service_role` key — non c'è un campo separato).
Agganciamento automatico alla pratica per barca+data, come il feedback.
Ogni riga sincronizzata viene tenuta quasi intatta nella forma in cui arriva da
Supabase (snake_case, dentro `.data`), non rimappata in camelCase: è la stessa
identica forma che `preference-list.html` si aspetta per la modalità di sola
lettura (vedi sotto), quindi non serve nessun adattatore.

**Stampa/PDF**: la pagina di dettaglio di una preference list ricevuta
(`renderPreferenceListDetail`) è già la vista "print" — nessun foglio compatto
separato come per le pratiche: si stampa con `window.print()` e le classi
`.no-print` esistenti nascondono i controlli.

**Link "sola lettura" per il comandante**: `buildCaptainLink()` prende l'intera
riga sincronizzata, ci aggiunge `_sender` (email dell'utente loggato), e la
codifica INTERAMENTE dentro l'URL (`?view=1&data=<json codificato>`) verso lo
stesso `preference-list.html`. Nessuna nuova lettura pubblica su Supabase è
stata aperta apposta per questo — i dati (passaporti, allergie, note mediche)
viaggiano solo dentro il link stesso, mai da un endpoint leggibile da chiunque
abbia la chiave `anon`. In `preference-list.html`, `?view=1` fa passare la
pagina in sola lettura: `hydrateStateFromPayload()` ricostruisce lo STATE
interattivo a partire dai dati ricevuti (stessa forma di `handleSubmit()`, solo
invertita), e tutte le sezioni vengono renderizzate dentro un
`<fieldset disabled>` — riusa le stesse funzioni di rendering del form
compilabile, niente è duplicato.

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
- I campi `type="date"`/`type="time"` si aggiornano su `blur`, **non** su
  `change` (vedi `liveEventFor()`) — i browser scatenano `change` ad ogni
  tasto se il campo ha già un valore, non solo alla fine, e ridisegnare a
  ogni colpo rimandava il focus alla prima cifra del campo data,
  interrompendo la digitazione. Stesso principio dei campi importo: non far
  scattare `render()`/`softRerenderCase()` più spesso del necessario mentre
  l'utente sta ancora scrivendo.
- **Tutte le cifre in euro si formattano con `fmtMoney()`/`fmtMoneyPlain()`**
  (migliaia separate da virgola, due decimali: `1,000.00`) — mai con
  `.toFixed(2)` direttamente. Dato che il valore VERO E PROPRIO dei campi
  `data-money` ora contiene la virgola delle migliaia (es. `"85,000.00"`),
  **`num()` la rimuove prima di fare `parseFloat`** — qualunque nuovo punto
  del codice che legga un campo importo deve passare da `num()`, mai da
  `parseFloat()`/`Number()` diretto, altrimenti il valore si tronca alla
  virgola.
- **Cascata "shortfall" a 3 tranche**: se un charter viene pagato dal
  cliente in 3 tranche invece delle 2 consuete, si riattiva (↺) il pagamento
  preimpostato ma nascosto di default "APA Balance from Client" (e il suo
  gemello "APA Balance to Owner", solo ruolo Central Agent) e lo si
  riordina prima di "APA + Delivery". Il suo importo effettivo (se
  presente) riduce lo scostamento (`balanceShortfall`) che altrimenti
  verrebbe scaricato per intero su "APA + Delivery" — vedi
  `netApaShortfall` in `buildScheduleItemsCharter()`. Il giroconto verso il
  Central Agent (ruolo Retail) non partecipa a questa cascata, per lo
  stesso motivo per cui non partecipa neanche a quella normale a 2 tranche.
- **`hiddenPayments` di default**: `newCase('charter')` nasconde già
  all'apertura i pagamenti di fine-charter meno frequenti (crew tip, APA
  refund, le due nuove righe "APA Balance") — si riattivano con "↺" come
  qualunque altro pagamento rimosso. Le pratiche già esistenti non vengono
  toccate retroattivamente.
- **Reconciliation** (`buildLedger()`) mostra solo i pagamenti con la
  spunta "pagato" confermata (non quelli previsti/in attesa), ordinati per
  data di pagamento effettiva — non per scadenza.

## File in questo repository
- `index.html` — l'applicazione
- `supabase-workspace-schema.sql` — schema per la modalità multiutente (tabella `workspace`)
- `supabase-schema.sql` — schema per la tabella `feedback` (usata da feedback-form.html, in un altro repository)
- `supabase-preference-list-schema.sql` — schema per la tabella `preference_lists` (usata da preference-list.html, repo `wci-yachts/preference-list-form`)
- `PROJECT_NOTES.md` — questo file
