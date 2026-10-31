package com.tempest.repforge.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

data class FoodProduct(
    val name: String,
    val brand: String,
    val barcode: String?,
    val kcalPer100g: Double,
    val proteinPer100g: Double,
    val carbsPer100g: Double,
    val fatPer100g: Double
)

object OpenFoodFacts {
    suspend fun search(query: String): List<FoodProduct> = withContext(Dispatchers.IO) {
        val encoded = URLEncoder.encode(query, "UTF-8")
        val url = URL("https://world.openfoodfacts.org/cgi/search.pl?search_terms=$encoded&search_simple=1&action=process&json=1&page_size=15&fields=code,product_name,brands,nutriments")
        val json = JSONObject(url.openConnection().apply {
            connectTimeout = 8000; readTimeout = 10000
            setRequestProperty("User-Agent", "RepForgeAndroid/0.1 (personal fitness tracker)")
        }.getInputStream().bufferedReader().use { it.readText() })
        val products = json.optJSONArray("products") ?: return@withContext emptyList()
        (0 until products.length()).mapNotNull { i ->
            val p = products.optJSONObject(i) ?: return@mapNotNull null
            val name = p.optString("product_name").trim()
            if (name.isBlank()) return@mapNotNull null
            val n = p.optJSONObject("nutriments") ?: JSONObject()
            FoodProduct(name, p.optString("brands"), p.optString("code").takeIf { it.isNotBlank() },
                n.optDouble("energy-kcal_100g", n.optDouble("energy-kcal_value", 0.0)),
                n.optDouble("proteins_100g", 0.0), n.optDouble("carbohydrates_100g", 0.0),
                n.optDouble("fat_100g", 0.0))
        }
    }

    suspend fun barcode(code: String): FoodProduct? = withContext(Dispatchers.IO) {
        val url = URL("https://world.openfoodfacts.org/api/v2/product/${URLEncoder.encode(code, "UTF-8")}.json")
        val conn = url.openConnection().apply {
            connectTimeout = 8000; readTimeout = 10000
            setRequestProperty("User-Agent", "RepForgeAndroid/0.1 (personal fitness tracker)")
        }
        val json = JSONObject(conn.getInputStream().bufferedReader().use { it.readText() })
        val p = json.optJSONObject("product") ?: return@withContext null
        if (json.optInt("status", 0) != 1) return@withContext null
        val n = p.optJSONObject("nutriments") ?: JSONObject()
        FoodProduct(p.optString("product_name", "Scanned product"), p.optString("brands"), code,
            n.optDouble("energy-kcal_100g", 0.0), n.optDouble("proteins_100g", 0.0),
            n.optDouble("carbohydrates_100g", 0.0), n.optDouble("fat_100g", 0.0))
    }
}
