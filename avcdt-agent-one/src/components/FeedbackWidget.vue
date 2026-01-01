<template>
  <div class="p-4 border rounded max-w-sm">
    <h3 class="text-lg font-medium">Feedback</h3>
    <p class="mt-2">Score: <strong>{{ score }}</strong></p>
    <div class="mt-3 flex gap-2">
      <button @click="upvote" aria-label="Upvote" class="px-3 py-1 bg-green-600 text-white rounded">▲</button>
      <button @click="downvote" aria-label="Downvote" class="px-3 py-1 bg-red-600 text-white rounded">▼</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'

const props = defineProps({ itemId: { type: String, required: true } })
const score = ref(0)
const STORAGE_KEY = `feedback_${props.itemId}`

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw !== null) score.value = Number(raw)
  } catch {}
}

function save() {
  try { localStorage.setItem(STORAGE_KEY, String(score.value)) } catch {}
}

function upvote() { score.value++; save() }
function downvote() { score.value--; save() }

onMounted(() => load())
</script>

<style scoped>
div { font-family: system-ui, sans-serif }
</style>
