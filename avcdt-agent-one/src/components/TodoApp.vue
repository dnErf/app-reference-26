<template>
  <div class="todo p-4 max-w-md">
    <h2 class="text-xl font-semibold">Todo App</h2>
    <div class="mt-3 flex">
      <input v-model="newText" @keyup.enter="addTodo" placeholder="Add todo" class="flex-1 px-2 py-1 border rounded" />
      <button @click="addTodo" class="ml-2 px-3 py-1 bg-blue-600 text-white rounded">Add</button>
    </div>

    <ul class="mt-4 space-y-2">
      <li v-for="item in todos" :key="item.id" class="flex items-center justify-between p-2 border rounded">
        <div class="flex items-center">
          <input type="checkbox" v-model="item.done" @change="save()" class="mr-3" />
          <span :class="{'line-through text-gray-500': item.done}">{{ item.text }}</span>
        </div>
        <div>
          <button @click="remove(item.id)" class="text-red-600">Remove</button>
        </div>
      </li>
    </ul>

    <p v-if="todos.length===0" class="mt-4 text-gray-500">No todos yet.</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'

const todos = ref([])
const newText = ref('')
const STORAGE_KEY = 'avcdt_todos'

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) todos.value = JSON.parse(raw)
  } catch (e) {
    todos.value = []
  }
}

function save() {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(todos.value)) } catch (e) {}
}

function addTodo() {
  const text = newText.value && newText.value.trim()
  if (!text) return
  todos.value.push({ id: Date.now(), text, done: false })
  newText.value = ''
  save()
}

function remove(id) {
  todos.value = todos.value.filter(t => t.id !== id)
  save()
}

onMounted(() => load())
</script>

<style scoped>
.todo { font-family: system-ui, sans-serif }
</style>
