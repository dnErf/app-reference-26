import type { ProductInCart, ProductInfo, Size } from "../../types"
import { atom, computed } from "nanostores"

export const $items = atom<ProductInCart[]>([])
export const $totalItems = computed($items, items => items.reduce((total, item) => total + item.quantity, 0))
export const $total = computed($items, items => items.reduce((sum, item) => sum + item.price * item.quantity, 0))

type Products = typeof $items

export function removeItemFromCart(items: Products, id: number, size: Size) {
    const subjectItems = items.get()
    const subjectIndex = subjectItems.findIndex((item) => item.id === id && item.size === size)
    if (subjectIndex !== -1) {
        items.set(subjectItems.splice(subjectIndex, 1))
    }
}

export function updateItemQuantityInCart(items: Products, id: number, size: Size, quantity: number) {
    const subjectIndex = items.get().findIndex((item) => item.id === id && item.size === size)
    if (subjectIndex !== -1) {
        const subjectItems = items.get()
        subjectItems[subjectIndex].quantity = quantity
        items.set(subjectItems)
    }
}

export function addToCart(items: Products, itemInCart: ProductInCart, size: Size, quantity: number) {
    const subjectIndex = items.get().findIndex((item) => item.id === itemInCart.id  && item.size === size)
    if (subjectIndex !== -1) {
        const subjectItems = items.get()
        subjectItems[subjectIndex].quantity += quantity
    }
    else {
        const subjectItems = items.get()
        subjectItems.push({ ...itemInCart, quantity, size })
        items.set(subjectItems)
    }
}
