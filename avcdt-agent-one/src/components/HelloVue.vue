<template>
  <div class="p-4 border rounded">
    <h2 class="text-lg font-semibold">Hello from Vue!</h2>
    <p class="mt-2">Count: {{ count }}</p>
    <button class="mt-3 px-3 py-1 bg-blue-600 text-white rounded" @click="count++">Increment</button>
  </div>
</template>

<script setup>
import { ref } from 'vue'
const count = ref(0)
</script>

<style scoped>
div { font-family: system-ui, sans-serif; }
</style>
