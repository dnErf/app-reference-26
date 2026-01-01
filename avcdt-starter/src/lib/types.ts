export const sizes = ["XS", "S", "M", "L", "XL"]

export type Size = (typeof sizes)[number]

export type ProductInfo = {
    id: number
    title: string
    image: string
    price: number
    description: string
    hasSize: boolean
}

export type ProductInCart = ProductInfo & {
    quantity: number
    size: Size
}
