package com.tempest.repforge.data

import android.content.Context
import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "recipes")
data class Recipe(
    @PrimaryKey val id: String,
    val name: String,
    val category: String,
    val description: String,
    val servings: Int,
    val caloriesPerServing: Double,
    val proteinPerServing: Double,
    val carbsPerServing: Double,
    val fatPerServing: Double,
    val ingredients: String,
    val method: String,
    val freezerFriendly: Boolean = true,
    val nutritionNote: String = "Estimated values; verify against actual ingredients and brands."
)

@Entity(tableName = "nutrition_entries")
data class NutritionEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: String,
    val meal: String,
    val name: String,
    val calories: Double,
    val protein: Double,
    val carbs: Double,
    val fat: Double,
    val servingNote: String = "1 serving",
    val barcode: String? = null
)

@Entity(tableName = "workout_logs")
data class WorkoutLog(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: String,
    val workoutName: String,
    val exerciseSummary: String,
    val completedSets: Int,
    val notes: String = ""
)

@Entity(tableName = "measurements")
data class MeasurementEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: String,
    val weightKg: Double? = null,
    val neckCm: Double? = null,
    val chestCm: Double? = null,
    val waistCm: Double? = null,
    val hipsCm: Double? = null,
    val thighRightCm: Double? = null,
    val thighLeftCm: Double? = null,
    val calfRightCm: Double? = null,
    val calfLeftCm: Double? = null,
    val bicepsRightCm: Double? = null,
    val bicepsLeftCm: Double? = null,
    val forearmRightCm: Double? = null,
    val forearmLeftCm: Double? = null,
    val notes: String = ""
)

@Entity(tableName = "workout_templates")
data class WorkoutTemplate(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val programmeName: String,
    val workoutName: String,
    // One exercise per line: Exercise name|sets|reps
    val exercises: String
)

@Dao
interface RepForgeDao {
    @Query("SELECT * FROM recipes ORDER BY category, name")
    fun recipes(): Flow<List<Recipe>>
    @Query("SELECT COUNT(*) FROM recipes")
    suspend fun recipeCount(): Int
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertRecipes(recipes: List<Recipe>)

    @Query("SELECT * FROM nutrition_entries WHERE date = :date ORDER BY id DESC")
    fun foodsForDate(date: String): Flow<List<NutritionEntry>>
    @Query("SELECT * FROM nutrition_entries ORDER BY date DESC, id DESC")
    fun allFoods(): Flow<List<NutritionEntry>>
    @Insert suspend fun insertFood(entry: NutritionEntry)
    @Delete suspend fun deleteFood(entry: NutritionEntry)

    @Query("SELECT * FROM workout_logs ORDER BY date DESC, id DESC")
    fun workoutLogs(): Flow<List<WorkoutLog>>
    @Insert suspend fun insertWorkout(log: WorkoutLog)

    @Query("SELECT * FROM measurements ORDER BY date ASC")
    fun measurements(): Flow<List<MeasurementEntry>>
    @Insert suspend fun insertMeasurement(entry: MeasurementEntry)
    @Query("DELETE FROM measurements WHERE id = :id")
    suspend fun deleteMeasurement(id: Long)

    @Query("SELECT * FROM workout_templates ORDER BY id ASC")
    fun templates(): Flow<List<WorkoutTemplate>>
    @Insert suspend fun insertTemplate(template: WorkoutTemplate)
    @Delete suspend fun deleteTemplate(template: WorkoutTemplate)
}

private val MIGRATION_1_2 = object : androidx.room.migration.Migration(1, 2) {
    override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
        database.execSQL("""CREATE TABLE IF NOT EXISTS recipes (
            id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL,
            description TEXT NOT NULL, servings INTEGER NOT NULL,
            caloriesPerServing REAL NOT NULL, proteinPerServing REAL NOT NULL,
            carbsPerServing REAL NOT NULL, fatPerServing REAL NOT NULL,
            ingredients TEXT NOT NULL, method TEXT NOT NULL,
            freezerFriendly INTEGER NOT NULL, nutritionNote TEXT NOT NULL
        )""")
    }
}

@Database(
    entities = [NutritionEntry::class, WorkoutLog::class, MeasurementEntry::class, WorkoutTemplate::class, Recipe::class],
    version = 2,
    exportSchema = false
)
abstract class RepForgeDatabase : RoomDatabase() {
    abstract fun dao(): RepForgeDao()
    companion object {
        @Volatile private var INSTANCE: RepForgeDatabase? = null
        fun get(context: Context): RepForgeDatabase = INSTANCE ?: synchronized(this) {
            INSTANCE ?: Room.databaseBuilder(context.applicationContext, RepForgeDatabase::class.java, "repforge.db")
                .addMigrations(MIGRATION_1_2).build().also { INSTANCE = it }
        }
    }
}
