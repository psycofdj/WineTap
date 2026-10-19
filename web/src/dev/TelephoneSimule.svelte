<script>
  // Panneau « Téléphone simulé » (développement seulement) : ce que ferait le téléphone.
  import { onMount } from 'svelte';

  let ouvert = $state(false);
  let etat = $state(/** @type {any} */ ({ sessions: [], scan: null, politique: { auto: true }, coupure: 0 }));

  async function rafraichir() {
    try {
      etat = await fetch('/__mock/etat').then((r) => r.json());
    } catch {
      /* serveur en redémarrage */
    }
  }

  async function action(chemin, corps = {}) {
    await fetch('/__mock/' + chemin, { method: 'POST', body: JSON.stringify(corps) });
    rafraichir();
  }

  onMount(() => {
    rafraichir();
    const t = setInterval(rafraichir, 1500);
    return () => clearInterval(t);
  });

  const attentes = $derived(etat.sessions.filter((s) => s.statut === 'en_attente'));
  const signal = $derived(attentes.length > 0 || !!etat.scan);
</script>

<div class="dev" class:ouvert>
  <button type="button" class="pastille" class:signal onclick={() => (ouvert = !ouvert)}>
    {signal ? '📱 Téléphone simulé · action attendue' : '📱 Téléphone simulé'}
  </button>
  {#if ouvert}
    <div class="corps">
      {#if etat.scan}
        <div class="bloc">
          <b>Lecture demandée ({etat.scan.objet})</b>
          <div class="ligne">
            <button type="button" onclick={() => action('scan', { action: 'nouveau' })}>Nouveau tag</button>
            <button type="button" onclick={() => action('scan', { action: 'existant' })}>Tag en stock</button>
            <button type="button" onclick={() => action('scan', { action: 'annuler' })}>Annuler</button>
          </div>
        </div>
      {/if}
      {#each attentes as s (s.id)}
        <div class="bloc">
          <b>Autoriser cette connexion ?</b>
          <span>{s.client.navigateur} sur {s.client.systeme} · {s.client.ip}</span>
          <div class="ligne">
            <button type="button" onclick={() => action('session', { id: s.id, statut: 'refusee' })}>Refuser</button>
            <button type="button" onclick={() => action('session', { id: s.id, statut: 'autorisee' })}>Autoriser</button>
          </div>
        </div>
      {/each}
      <div class="bloc">
        <label><input type="checkbox" checked={etat.politique.auto} onchange={(e) => action('politique', { auto: e.currentTarget.checked })} /> Autoriser automatiquement</label>
        <div class="ligne">
          <button type="button" onclick={() => action('consommer-sur-telephone')}>Consommer sur le téléphone</button>
          <button type="button" onclick={() => action('couper', { secondes: 12 })}>Couper 12 s</button>
        </div>
        <div class="ligne">
          <button type="button" onclick={() => action('session', { statut: 'inconnue' })}>Révoquer ce navigateur</button>
          <button type="button" onclick={() => action('vider')}>Vider la cave</button>
          <button type="button" onclick={() => action('reinitialiser')}>Réinitialiser</button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .dev {
    position: fixed;
    left: 10px;
    bottom: 10px;
    z-index: 200;
    font: 12px/1.4 system-ui, sans-serif;
    color: #222;
  }
  .pastille {
    border: 1px dashed #999;
    background: rgba(255, 255, 255, 0.92);
    border-radius: 999px;
    padding: 4px 10px;
    font-size: 11px;
    color: #555;
  }
  .pastille.signal {
    border-color: #c60;
    color: #c60;
    font-weight: 600;
  }
  .corps {
    margin-top: 6px;
    width: 320px;
    background: #fff;
    border: 1px solid #ccc;
    border-radius: 10px;
    padding: 10px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .bloc {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .ligne {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .ligne button {
    border: 1px solid #bbb;
    background: #f6f6f6;
    border-radius: 6px;
    padding: 4px 8px;
    font-size: 12px;
  }
</style>
