<template>
  <div class="p-4 border rounded">
    <h3 class="text-lg font-medium">Status Widget</h3>
    <p class="mt-2">{{ message }}</p>
    <p class="mt-2">Clicks: {{ count }}</p>
    <button class="mt-3 px-3 py-1 bg-green-600 text-white rounded" @click="count++">Click</button>
  </div>
</template>

<script setup>
import { ref, defineProps } from 'vue'
const props = defineProps({ message: { type: String, default: 'All systems nominal.' } })
const count = ref(0)
const message = props.message
</script>

<style scoped>
div { font-family: system-ui, sans-serif; }
</style>
