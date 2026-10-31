package com.tempest.repforge

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import com.google.android.gms.mlkit.codescanner.GmsBarcodeScanning
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.tempest.repforge.data.*
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val Ink = Color(0xFF10141C)
private val Panel = Color(0xFF181E29)
private val Panel2 = Color(0xFF202838)
private val Electric = Color(0xFF00AEEF)
private val Purple = Color(0xFF8C71E8)
private val Green = Color(0xFF4FD1A1)
private val Muted = Color(0xFF9AA6B8)
private val Border = Color(0xFF2B3545)

class MainActivity : ComponentActivity() {
    private lateinit var dao: RepForgeDao
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dao = RepForgeDatabase.get(this).dao()
        lifecycleScope.launch {
            dao.insertRecipes(defaultStarterRecipes())
        }
        setContent { RepForgeApp(dao, this) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepForgeApp(dao: RepForgeDao, activity: Activity) {
    var tab by remember { mutableStateOf(0) }
    var caloriesTarget by remember { mutableStateOf("2400") }
    var proteinTarget by remember { mutableStateOf("180") }
    var carbsTarget by remember { mutableStateOf("250") }
    var fatTarget by remember { mutableStateOf("75") }
    val today = LocalDate.now().toString()
    val foods by dao.foodsForDate(today).collectAsStateWithLifecycle(emptyList())
    val logs by dao.workoutLogs().collectAsStateWithLifecycle(emptyList())
    val measurements by dao.measurements().collectAsStateWithLifecycle(emptyList())
    val templates by dao.templates().collectAsStateWithLifecycle(emptyList())
    val recipes by dao.recipes().collectAsStateWithLifecycle(emptyList())
    val scope = rememberCoroutineScope()
    var snackbar by remember { mutableStateOf<String?>(null) }
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(snackbar) {
        snackbar?.let {
            snackbarHostState.showSnackbar(it)
            snackbar = null
        }
    }

    MaterialTheme(colorScheme = darkColorScheme(
        primary = Electric, onPrimary = Ink, background = Ink, surface = Panel,
        onSurface = Color(0xFFF1F4F9), secondary = Purple, outline = Border
    )) {
        Scaffold(
            containerColor = Ink,
            topBar = {
                Row(Modifier.fillMaxWidth().background(Ink).padding(horizontal=18.dp, vertical=14.dp), verticalAlignment=Alignment.CenterVertically) {
                    Box(Modifier.size(38.dp).background(Electric, RoundedCornerShape(10.dp)), contentAlignment=Alignment.Center) {
                        Text("R", fontSize=25.sp, fontWeight=FontWeight.Black, color=Ink)
                    }
                    Spacer(Modifier.width(11.dp))
                    Column {
                        Text("REPFORGE", fontSize=18.sp, fontWeight=FontWeight.Black, letterSpacing=1.8.sp)
                        Text("NUTRITION × STRENGTH", fontSize=9.sp, color=Muted, letterSpacing=1.2.sp)
                    }
                }
            },
            bottomBar = {
                NavigationBar(containerColor=Panel, contentColor=Muted) {
                    val items = listOf("Home", "Food", "Recipes", "Train", "Progress", "Settings")
                    val icons = listOf(Icons.Default.Dashboard, Icons.Default.Restaurant, Icons.Default.MenuBook, Icons.Default.FitnessCenter, Icons.Default.ShowChart, Icons.Default.Tune)
                    items.forEachIndexed { i, label ->
                        NavigationBarItem(selected=tab==i, onClick={tab=i}, icon={Icon(icons[i], contentDescription=label)}, label={Text(label, fontSize=10.sp)}, colors=NavigationBarItemDefaults.colors(selectedIconColor=Electric, selectedTextColor=Electric, indicatorColor=Panel2, unselectedIconColor=Muted, unselectedTextColor=Muted))
                    }
                }
            },
            snackbarHost = { SnackbarHost(snackbarHostState) }
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).padding(horizontal=16.dp)) {
                when(tab) {
                    0 -> HomeScreen(foods, caloriesTarget.toDoubleOrNull()?:2400.0, proteinTarget.toDoubleOrNull()?:180.0, carbsTarget.toDoubleOrNull()?:250.0, fatTarget.toDoubleOrNull()?:75.0, templates, measurements, logs, onGoFood={tab=1}, onGoTrain={tab=2})
                    1 -> FoodScreen(dao, foods, today, activity, onScan={
                        try {
                            val task = GmsBarcodeScanning.getClient(activity).startScan()
                            task.addOnSuccessListener { barcode ->
                                val code = barcode.rawValue
                                if (!code.isNullOrBlank()) scope.launch {
                                    try {
                                        val p = OpenFoodFacts.barcode(code)
                                        if (p != null) dao.insertFood(NutritionEntry(date=today, meal="Snacks", name=p.name, calories=p.kcalPer100g, protein=p.proteinPer100g, carbs=p.carbsPer100g, fat=p.fatPer100g, servingNote="per 100 g", barcode=code))
                                        else snackbar="Barcode not found"
                                    } catch (_: Exception) { snackbar="Barcode lookup failed" }
                                }
                            }.addOnFailureListener { snackbar="Barcode scan cancelled or unavailable" }
                        } catch (_: Exception) { snackbar="Barcode scanner unavailable on this device" }
                    }, notify={snackbar=it})
                    2 -> RecipesScreen(dao, recipes, today, notify={snackbar=it})
                    3 -> TrainingScreen(dao, templates, logs, notify={snackbar=it})
                    4 -> ProgressScreen(dao, measurements, notify={snackbar=it})
                    else -> SettingsScreen(caloriesTarget, {caloriesTarget=it}, proteinTarget,{proteinTarget=it}, carbsTarget,{carbsTarget=it},fatTarget,{fatTarget=it})
                }
            }
        }
    }
}

@Composable fun ScreenTitle(kicker:String, title:String) {
    Spacer(Modifier.height(14.dp)); Text(kicker.uppercase(), color=Electric, fontSize=10.sp, letterSpacing=1.7.sp, fontWeight=FontWeight.Bold)
    Text(title, fontSize=31.sp, fontWeight=FontWeight.Bold, letterSpacing=(-.6).sp)
    Spacer(Modifier.height(12.dp))
}
@Composable fun PanelCard(content:@Composable ColumnScope.()->Unit) {
    Column(Modifier.fillMaxWidth().padding(bottom=12.dp).background(Panel, RoundedCornerShape(16.dp)).padding(16.dp), content=content)
}
@Composable fun SectionTitle(title:String, action:String?=null, onAction:(()->Unit)?=null) {
    Row(Modifier.fillMaxWidth().padding(top=8.dp,bottom=10.dp), horizontalArrangement=Arrangement.SpaceBetween, verticalAlignment=Alignment.CenterVertically) {
        Text(title, fontSize=17.sp, fontWeight=FontWeight.SemiBold)
        if(action!=null && onAction!=null) TextButton(onClick=onAction, contentPadding=PaddingValues(0.dp)) { Text(action, color=Electric) }
    }
}
@Composable fun MacroBar(label:String, amount:Double, target:Double, color:Color) {
    Column(Modifier.padding(vertical=6.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.SpaceBetween) {
            Text(label, color=Muted, fontSize=12.sp); Text("${amount.toInt()} / ${target.toInt()} g", fontSize=12.sp, fontWeight=FontWeight.SemiBold)
        }
        Spacer(Modifier.height(5.dp)); Box(Modifier.fillMaxWidth().height(6.dp).background(Panel2, CircleShape)) {
            Box(Modifier.fillMaxWidth((if(target>0)(amount/target).coerceIn(0.0,1.0).toFloat() else 0f)).fillMaxHeight().background(color, CircleShape))
        }
    }
}
@Composable fun HomeScreen(foods:List<NutritionEntry>, calTarget:Double, pTarget:Double, cTarget:Double, fTarget:Double, templates:List<WorkoutTemplate>, measurements:List<MeasurementEntry>, logs:List<WorkoutLog>, onGoFood:()->Unit,onGoTrain:()->Unit) {
    val calories=foods.sumOf{it.calories}; val protein=foods.sumOf{it.protein}; val carbs=foods.sumOf{it.carbs}; val fat=foods.sumOf{it.fat}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        ScreenTitle(LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE, d MMMM")).uppercase(),"Your cockpit.")
        Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
            PanelCard { Text("CALORIES", color=Muted, fontSize=10.sp, letterSpacing=1.sp); Text("${(calTarget-calories).toInt()}", fontSize=30.sp, fontWeight=FontWeight.Bold); Text("kcal remaining", color=Muted, fontSize=11.sp); Spacer(Modifier.height(8.dp)); LinearProgressIndicator(progress={(calories/calTarget).coerceIn(0.0,1.0).toFloat()}, color=Electric, trackColor=Panel2, modifier=Modifier.fillMaxWidth()); Text("${calories.toInt()} eaten · ${calTarget.toInt()} target", color=Muted, fontSize=10.sp) }
            PanelCard { Text("PROTEIN", color=Muted, fontSize=10.sp, letterSpacing=1.sp); Text("${protein.toInt()} g", fontSize=30.sp, fontWeight=FontWeight.Bold); Text("of ${pTarget.toInt()} g target", color=Muted, fontSize=11.sp); Spacer(Modifier.height(8.dp)); LinearProgressIndicator(progress={(protein/pTarget).coerceIn(0.0,1.0).toFloat()}, color=Purple, trackColor=Panel2, modifier=Modifier.fillMaxWidth()) }
        }
        PanelCard { Text("MACROS", fontSize=11.sp, letterSpacing=1.2.sp, color=Muted); MacroBar("Protein",protein,pTarget,Purple); MacroBar("Carbohydrates",carbs,cTarget,Electric); MacroBar("Fat",fat,fTarget,Green) }
        SectionTitle("Today's food diary","Add food",onGoFood)
        PanelCard { if(foods.isEmpty()) Text("Nothing logged yet. Add your first meal.",color=Muted) else foods.forEach { Text(it.name,fontWeight=FontWeight.Medium); Text("${it.meal} · ${it.calories.toInt()} kcal · P ${it.protein.toInt()}g / C ${it.carbs.toInt()}g / F ${it.fat.toInt()}g",fontSize=11.sp,color=Muted); HorizontalDivider(color=Border); Spacer(Modifier.height(5.dp)) } }
        SectionTitle("Next session","Open training",onGoTrain)
        PanelCard { val t=templates.firstOrNull(); if(t==null) Text("Create your first workout template in Training.",color=Muted) else { Text("${t.programmeName} · ${t.workoutName}",fontWeight=FontWeight.SemiBold); Text(t.exercises.lines().joinToString(" · "){it.substringBefore("|")},color=Muted,fontSize=12.sp) } }
        Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
            PanelCard { Text("LATEST WEIGHT",color=Muted,fontSize=10.sp); Text(measurements.lastOrNull{it.weightKg!=null}?.let{"${it.weightKg} kg"}?: "—",fontSize=24.sp,fontWeight=FontWeight.Bold) }
            PanelCard { Text("WORKOUTS LOGGED",color=Muted,fontSize=10.sp); Text("${logs.size}",fontSize=24.sp,fontWeight=FontWeight.Bold) }
        }
        Spacer(Modifier.height(12.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun FoodScreen(dao:RepForgeDao, foods:List<NutritionEntry>, today:String, activity:Activity, onScan:()->Unit, notify:(String)->Unit) {
    var query by remember { mutableStateOf("") }; var results by remember { mutableStateOf<List<FoodProduct>>(emptyList()) }; var searching by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }; var kcal by remember { mutableStateOf("") }; var protein by remember { mutableStateOf("") }; var carbs by remember { mutableStateOf("") }; var fat by remember { mutableStateOf("") }; var meal by remember { mutableStateOf("Breakfast") }; var servings by remember { mutableStateOf("1") }
    val scope= rememberCoroutineScope()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        ScreenTitle("Fuel the work","Nutrition.")
        PanelCard {
            Text("FOOD DATABASE",color=Muted,fontSize=10.sp,letterSpacing=1.sp); Spacer(Modifier.height(8.dp))
            OutlinedTextField(query,{query=it},label={Text("Search food or brand")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                Button(onClick={if(query.isNotBlank()){searching=true;scope.launch { try { results=OpenFoodFacts.search(query); if(results.isEmpty())notify("No results found") } catch(_:Exception){notify("Food search failed. Check your connection")} finally{searching=false} }}},modifier=Modifier.weight(1f)) { Text(if(searching)"Searching…" else "Search") }
                OutlinedButton(onClick=onScan,modifier=Modifier.weight(1f)) { Icon(Icons.Default.QrCodeScanner,null); Spacer(Modifier.width(5.dp)); Text("Scan barcode") }
            }
            results.forEach { p ->
                HorizontalDivider(color=Border)
                Row(Modifier.fillMaxWidth().padding(vertical=9.dp),verticalAlignment=Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) { Text(p.name,fontWeight=FontWeight.SemiBold); Text("${p.brand} · ${p.kcalPer100g.toInt()} kcal/100g",color=Muted,fontSize=11.sp) }
                    TextButton(onClick={scope.launch { dao.insertFood(NutritionEntry(date=today,meal=meal,name=p.name,calories=p.kcalPer100g,protein=p.proteinPer100g,carbs=p.carbsPer100g,fat=p.fatPer100g,servingNote="per 100 g",barcode=p.barcode));notify("Added per 100 g; adjust portion as needed") }}) { Text("Add") }
                }
            }
            Text("Product data is crowdsourced. Verify the label and serving size.",color=Muted,fontSize=10.sp)
        }
        PanelCard {
            Text("QUICK ADD",color=Muted,fontSize=10.sp,letterSpacing=1.sp); Spacer(Modifier.height(8.dp))
            OutlinedTextField(name,{name=it},label={Text("Food name")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) { OutlinedTextField(kcal,{kcal=it},label={Text("kcal")},modifier=Modifier.weight(1f)); OutlinedTextField(protein,{protein=it},label={Text("Protein g")},modifier=Modifier.weight(1f)) }
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) { OutlinedTextField(carbs,{carbs=it},label={Text("Carbs g")},modifier=Modifier.weight(1f)); OutlinedTextField(fat,{fat=it},label={Text("Fat g")},modifier=Modifier.weight(1f)) }
            OutlinedTextField(servings,{servings=it},label={Text("Servings")},modifier=Modifier.fillMaxWidth())
            var expanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}) {
                OutlinedTextField(value=meal, onValueChange={}, label={Text("Meal")}, modifier=Modifier.fillMaxWidth().menuAnchor(), readOnly=true, trailingIcon={ExposedDropdownMenuDefaults.TrailingIcon(expanded)})
                ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) { listOf("Breakfast","Lunch","Dinner","Snacks").forEach { DropdownMenuItem(text={Text(it)},onClick={meal=it;expanded=false}) } }
            }
            Button(onClick={if(name.isBlank()){notify("Enter a food name")}else{val s=(servings.toDoubleOrNull()?:1.0).coerceAtLeast(.1);scope.launch{dao.insertFood(NutritionEntry(date=today,meal=meal,name=name,calories=(kcal.toDoubleOrNull()?:0.0)*s,protein=(protein.toDoubleOrNull()?:0.0)*s,carbs=(carbs.toDoubleOrNull()?:0.0)*s,fat=(fat.toDoubleOrNull()?:0.0)*s,servingNote="$s serving(s)"));name="";kcal="";protein="";carbs="";fat="";servings="1";notify("Food added")}}},modifier=Modifier.fillMaxWidth()) { Text("Add to diary") }
        }
        PanelCard { Text("TODAY'S DIARY",fontWeight=FontWeight.SemiBold); Spacer(Modifier.height(8.dp)); if(foods.isEmpty()) Text("No food entries yet",color=Muted) else foods.forEach { f -> Row(Modifier.fillMaxWidth().padding(vertical=7.dp),horizontalArrangement=Arrangement.SpaceBetween) { Column(Modifier.weight(1f)) { Text(f.name); Text("${f.meal} · P ${f.protein.toInt()}g · C ${f.carbs.toInt()}g · F ${f.fat.toInt()}g",color=Muted,fontSize=10.sp) }; Column(horizontalAlignment=Alignment.End) { Text("${f.calories.toInt()} kcal",fontWeight=FontWeight.SemiBold); TextButton(onClick={scope.launch{dao.deleteFood(f)}}){Text("Remove",color=Color(0xFFFF6D7A))} } }; HorizontalDivider(color=Border) } }
        Spacer(Modifier.height(20.dp))
    }
}


private fun defaultStarterRecipes() = listOf(
    Recipe(
        id = "starter-chicken-burrito-001",
        name = "Smoky Chicken Burrito Wrap",
        category = "Lunch",
        description = "Batch-cooked chicken, rice, black beans, peppers and reduced-fat cheddar in a wholemeal tortilla.",
        servings = 8,
        caloriesPerServing = 460.0,
        proteinPerServing = 43.0,
        carbsPerServing = 48.0,
        fatPerServing = 11.0,
        ingredients = """1 kg chicken breast
8 large wholemeal tortillas
400 g cooked rice
240 g drained black beans
2 red peppers
1 large red onion
120 g reduced-fat mature cheddar
2 tbsp tomato purée
1 tbsp olive oil
Juice of 1 lime
2 tsp smoked paprika
2 tsp ground cumin
1 tsp garlic granules
1 tsp onion granules
½ tsp chilli powder
½ tsp oregano
Salt, black pepper and optional fresh coriander""",
        method = """1. Dice the chicken and coat with the tomato purée, smoked paprika, cumin, garlic, onion granules, chilli, oregano, salt and pepper.
2. Heat half the oil in a large pan and cook the chicken until golden and cooked through.
3. Slice the peppers and onion. Cook in the remaining oil until softened but still slightly firm.
4. Stir in the drained black beans, cooked rice, chicken and lime juice.
5. Cool the filling promptly, then divide evenly between the 8 tortillas.
6. Add the cheddar and optional coriander. Fold tightly into burritos.
7. Optionally toast the sealed wraps briefly in a dry pan. Cool completely, wrap individually and freeze.
8. Reheat from frozen after removing foil, or defrost overnight in the fridge and reheat until piping hot throughout.""",
        freezerFriendly = true,
        nutritionNote = "Approximate starting estimate per wrap: 460 kcal, 43 g protein, 48 g carbohydrate, 11 g fat. Actual values depend on tortilla size, cooked rice weight, chicken yield and cheese brand. Recalculate when exact products/weights are known."
    ),
    Recipe(
        id = "starter-brisket-lasagne-001",
        name = "Slow-Braised Brisket & Pork Lasagne",
        category = "Dinner",
        description = "Long-braised shredded beef brisket and pork mince ragù layered with Parmesan béchamel, pasta and mozzarella.",
        servings = 10,
        caloriesPerServing = 600.0,
        proteinPerServing = 44.0,
        carbsPerServing = 50.0,
        fatPerServing = 25.0,
        ingredients = """1–1.2 kg beef brisket
400 g pork mince
2 onions
2 carrots
2 celery sticks
4 garlic cloves
2 tbsp tomato purée
2 × 400 g tins chopped tomatoes
300 ml beef stock
150 ml red wine
1 tbsp Worcestershire sauce
2 tsp dried oregano
2 bay leaves, rosemary and thyme
Salt, black pepper and olive oil
70 g butter
70 g plain flour
800 ml whole milk
60 g Parmesan, plus extra for topping
Lasagne sheets
150 g mozzarella
Pinch of nutmeg""",
        method = """1. Season the brisket generously. Sear in a hot pan with a little oil until deeply browned on all sides; set aside.
2. In the same pan, brown the pork mince. Add finely diced onion, carrot and celery and cook for 8–10 minutes.
3. Add garlic and tomato purée; cook for 2 minutes. Deglaze with red wine, scraping up the browned fond.
4. Transfer to the slow cooker. Add tomatoes, stock, Worcestershire sauce, oregano, bay leaves and herbs. Nestle in the brisket.
5. Cook on LOW for approximately 8–9 hours, until the brisket pulls apart easily. Check doneness rather than relying on time alone.
6. Remove brisket, shred it and discard large pieces of connective tissue or excess fat. Remove bay leaves and herb stalks; return shredded beef to the sauce.
7. If the ragù is loose, reduce it uncovered in a saucepan until thick. Cool promptly if not assembling immediately.
8. For the béchamel, melt butter, stir in flour and cook for 2 minutes. Gradually whisk in milk; simmer until thick. Add Parmesan, nutmeg, salt and white pepper.
9. Layer ragù, lasagne sheets and béchamel. Repeat, finishing with béchamel, mozzarella and extra Parmesan.
10. Bake at 180°C fan for approximately 40–45 minutes until golden and bubbling. Rest for 20 minutes before portioning.
11. For meal prep, cool promptly, divide into 10 portions and refrigerate or freeze. Reheat until piping hot throughout.""",
        freezerFriendly = true,
        nutritionNote = "Approximate planning estimate per 1/10 batch: 600 kcal, 44 g protein, 50 g carbohydrate, 25 g fat. This is provisional: brisket trim, pork mince fat %, pasta quantity, cheese and final cooked yield will materially change the result. Recalculate from actual ingredient labels and weights."
    ),
    Recipe(
        id = "starter-korean-sticky-beef-001",
        name = "Korean Sticky Beef Bowls",
        category = "Dinner",
        description = "Korean-inspired beef mince with gochujang, broccoli, edamame and jasmine rice.",
        servings = 4,
        caloriesPerServing = 520.0,
        proteinPerServing = 46.0,
        carbsPerServing = 58.0,
        fatPerServing = 12.0,
        ingredients = """600 g 5% beef mince
240 g jasmine rice (dry)
200 g shelled edamame
300 g broccoli
30 g gochujang
30 ml reduced-salt soy sauce
20 g honey
2 garlic cloves, 20 g fresh ginger
5 ml sesame oil
Spring onions and sesame seeds""",
        method = """1. Cook the rice according to the packet instructions.
2. Brown the beef mince in a large non-stick pan, breaking it up as it cooks.
3. Add garlic and ginger; cook for 1 minute.
4. Mix gochujang, soy sauce and honey with 2 tbsp water. Add to the beef and simmer until glossy.
5. Steam broccoli and edamame until tender.
6. Divide rice, beef and vegetables between four containers. Finish with spring onion and sesame.
7. Refrigerate promptly; freeze the beef and rice portions if keeping longer. Reheat until piping hot.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-turkey-kofta-001",
        name = "Mediterranean Turkey Kofta Bowls",
        category = "Dinner",
        description = "Herby turkey koftas with wholewheat couscous, chopped salad, feta and lemon yoghurt.",
        servings = 4,
        caloriesPerServing = 520.0,
        proteinPerServing = 48.0,
        carbsPerServing = 48.0,
        fatPerServing = 14.0,
        ingredients = """600 g lean turkey mince
200 g wholewheat couscous (dry)
150 g 0% Greek yoghurt
100 g reduced-fat feta
250 g tomatoes
½ cucumber
½ red onion
1 lemon
2 tsp cumin, 1 tsp ground coriander, 1 tsp paprika
Dried oregano, garlic and parsley""",
        method = """1. Heat the oven to 200°C fan.
2. Mix turkey with cumin, coriander, paprika, oregano, crushed garlic, parsley, salt and pepper.
3. Shape into 12 small koftas and place on a lined tray. Bake for 18–22 minutes until cooked through.
4. Prepare couscous with boiling water according to the packet.
5. Chop tomatoes, cucumber and onion. Mix yoghurt with lemon juice and garlic.
6. Divide couscous, koftas and salad between four bowls. Add feta and lemon yoghurt.
7. Keep salad and yoghurt separate for best meal-prep texture.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-thai-green-chicken-001",
        name = "Thai Green Curry Chicken",
        category = "Dinner",
        description = "Chicken breast simmered in green curry and light coconut milk with crisp vegetables and jasmine rice.",
        servings = 4,
        caloriesPerServing = 550.0,
        proteinPerServing = 48.0,
        carbsPerServing = 62.0,
        fatPerServing = 12.0,
        ingredients = """700 g chicken breast
240 g jasmine rice (dry)
100 g Thai green curry paste
400 ml light coconut milk
300 g green beans
2 peppers
1 tbsp fish sauce
1 lime
Fresh basil""",
        method = """1. Cook rice separately.
2. Dice chicken. Heat a large pan and brown chicken in batches.
3. Add curry paste and cook for 1 minute until fragrant.
4. Pour in coconut milk and simmer gently until chicken is cooked through.
5. Add sliced peppers and green beans for the final 6–8 minutes.
6. Season with fish sauce and lime juice; finish with basil.
7. Cool promptly. Freeze curry separately from rice for best texture; reheat until piping hot.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-pork-carnitas-001",
        name = "Mexican Pork Carnitas Bowls",
        category = "Dinner",
        description = "Citrus, cumin and chipotle pulled pork with rice, black beans, corn and fresh salsa.",
        servings = 4,
        caloriesPerServing = 550.0,
        proteinPerServing = 45.0,
        carbsPerServing = 60.0,
        fatPerServing = 13.0,
        ingredients = """700 g lean pork loin or trimmed pork shoulder
200 g rice (dry)
1 × 400 g tin black beans, drained
150 g sweetcorn
2 oranges
2 limes
2 tsp cumin, 2 tsp smoked paprika, 1 tsp oregano
2 garlic cloves
Chipotle paste to taste
Tomato, red onion and coriander for salsa""",
        method = """1. Put pork in a slow cooker with orange juice, lime juice, garlic, cumin, paprika, oregano and chipotle.
2. Cook on LOW for 6–8 hours (loin may cook sooner; shoulder generally needs longer) until tender and safely cooked.
3. Shred the pork and reduce the cooking liquid in a pan to make a glaze.
4. Cook rice. Warm beans and corn.
5. Make a fresh salsa from chopped tomato, red onion, coriander and lime.
6. Divide rice, pork, beans and corn into four portions. Add salsa when serving.
7. Freeze pork, rice and beans; add fresh salsa after reheating.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-harissa-chicken-001",
        name = "Moroccan Harissa Chicken & Pearl Couscous",
        category = "Dinner",
        description = "Harissa-spiced chicken with chickpeas, roasted vegetables, pearl couscous and cooling yoghurt.",
        servings = 4,
        caloriesPerServing = 530.0,
        proteinPerServing = 50.0,
        carbsPerServing = 55.0,
        fatPerServing = 10.0,
        ingredients = """700 g chicken breast
200 g pearl couscous (dry)
1 × 400 g tin chickpeas, drained
2 courgettes
1 aubergine
1 red onion
40 g harissa paste
150 g 0% Greek yoghurt
1 lemon
Cumin, cinnamon and garlic""",
        method = """1. Heat oven to 200°C fan. Chop courgette, aubergine and onion; toss with half the harissa and roast for 25–30 minutes.
2. Coat chicken with remaining harissa, cumin, garlic and lemon zest.
3. Roast chicken on a separate tray until cooked through, then rest and slice.
4. Cook pearl couscous according to packet instructions. Stir through drained chickpeas and lemon juice.
5. Mix yoghurt with lemon juice and a pinch of salt.
6. Divide couscous, vegetables and chicken between four portions. Serve with yoghurt.
7. Cool promptly and freeze without the yoghurt garnish.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-cajun-salmon-001",
        name = "Cajun Salmon & Sweet Potato",
        category = "Dinner",
        description = "Cajun-seasoned salmon with roasted sweet potato, broccoli and lemon-garlic yoghurt.",
        servings = 4,
        caloriesPerServing = 550.0,
        proteinPerServing = 43.0,
        carbsPerServing = 48.0,
        fatPerServing = 21.0,
        ingredients = """600 g salmon fillets
800 g sweet potato
400 g broccoli
150 g 0% Greek yoghurt
Cajun seasoning
1 lemon
1 garlic clove
1 tsp olive oil""",
        method = """1. Heat oven to 200°C fan. Cube sweet potato, toss with olive oil and roast for 25–30 minutes.
2. Season salmon with Cajun seasoning and bake for 12–15 minutes, depending on thickness, until just cooked.
3. Steam broccoli until tender.
4. Mix yoghurt with lemon juice, grated garlic and black pepper.
5. Divide salmon, sweet potato and broccoli between four plates or containers.
6. Keep yoghurt dressing separate. Refrigerate cooked salmon promptly and use within 1–2 days; freezing is possible but may soften its texture.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-chicken-meatball-orzo-001",
        name = "Italian Chicken Meatball Orzo",
        category = "Dinner",
        description = "Lean chicken meatballs simmered with tomato, spinach and orzo, finished with Parmesan.",
        servings = 4,
        caloriesPerServing = 540.0,
        proteinPerServing = 49.0,
        carbsPerServing = 58.0,
        fatPerServing = 12.0,
        ingredients = """600 g lean chicken mince
240 g orzo (dry)
1 egg
1 × 400 g tin chopped tomatoes
500 ml chicken stock
150 g spinach
40 g Parmesan
2 garlic cloves
Dried basil and oregano""",
        method = """1. Mix chicken mince with egg, half the garlic, basil, oregano, salt and pepper. Shape into 16 meatballs.
2. Brown meatballs in a large deep pan; remove temporarily.
3. Add remaining garlic and chopped tomatoes. Pour in stock and bring to a simmer.
4. Stir in orzo and return meatballs to the pan. Simmer, stirring regularly, until orzo is tender and meatballs are cooked through; add water if needed.
5. Fold in spinach and Parmesan.
6. Divide into four portions. This thickens as it stands; loosen with a splash of water when reheating.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-teriyaki-prawn-001",
        name = "Japanese Teriyaki Prawn Noodles",
        category = "Dinner",
        description = "King prawns and udon noodles tossed with edamame, pak choi and a ginger-teriyaki glaze.",
        servings = 4,
        caloriesPerServing = 490.0,
        proteinPerServing = 43.0,
        carbsPerServing = 62.0,
        fatPerServing = 7.0,
        ingredients = """600 g raw king prawns, peeled
600 g fresh udon noodles
200 g shelled edamame
2 pak choi
2 carrots
50 ml reduced-salt soy sauce
30 ml mirin
20 g honey
2 garlic cloves and 20 g ginger
Lime juice""",
        method = """1. Mix soy sauce, mirin, honey, grated ginger, garlic and a squeeze of lime.
2. Stir-fry sliced carrots and pak choi in a large hot pan.
3. Add prawns and cook until pink and opaque.
4. Add edamame, udon noodles and sauce. Toss until hot and evenly coated.
5. Divide into four portions.
6. Refrigerate promptly and use within 1–2 days. Reheat thoroughly only once; prawns can become tough if overcooked.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-greek-stuffed-peppers-001",
        name = "Greek Beef Stuffed Peppers",
        category = "Dinner",
        description = "Lean beef, rice, tomato, spinach and oregano baked in peppers with a little feta.",
        servings = 4,
        caloriesPerServing = 500.0,
        proteinPerServing = 44.0,
        carbsPerServing = 48.0,
        fatPerServing = 14.0,
        ingredients = """600 g 5% beef mince
160 g rice (dry)
4 large peppers
1 × 400 g tin chopped tomatoes
80 g reduced-fat feta
100 g spinach
1 onion
2 garlic cloves
Oregano, cinnamon, lemon and parsley""",
        method = """1. Heat oven to 190°C fan. Halve peppers lengthways and remove seeds.
2. Cook rice until just tender.
3. Brown beef with chopped onion and garlic. Add tomatoes, oregano and a small pinch of cinnamon; simmer for 10 minutes.
4. Stir in spinach and cooked rice.
5. Fill pepper halves, top with crumbled feta and bake for 25–30 minutes until peppers are tender and filling is piping hot.
6. Cool promptly and portion. Refrigerate or freeze.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-lighter-butter-chicken-001",
        name = "Lighter Indian Butter Chicken",
        category = "Dinner",
        description = "Yoghurt-marinated chicken in a gently spiced tomato, butter and light-cream sauce with spinach.",
        servings = 4,
        caloriesPerServing = 550.0,
        proteinPerServing = 50.0,
        carbsPerServing = 55.0,
        fatPerServing = 14.0,
        ingredients = """700 g chicken breast
200 g basmati rice (dry)
1 × 400 g tin chopped tomatoes
150 g 0% Greek yoghurt
20 g butter
50 ml reduced-fat single cream
100 g spinach
Garam masala, cumin, paprika and dried fenugreek
Ginger and garlic""",
        method = """1. Coat chicken pieces in yoghurt, garam masala, cumin, paprika, garlic and ginger. Marinate for at least 30 minutes if time allows.
2. Brown chicken in a non-stick pan; remove.
3. Melt butter, add a little garlic and ginger, then tomatoes and fenugreek. Simmer for 10 minutes; blend if a smooth sauce is preferred.
4. Return chicken and simmer until cooked through.
5. Stir in cream and spinach. Adjust seasoning.
6. Cook rice separately and divide into four portions with the curry.
7. Freeze curry and rice in separate portions.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-sausage-egg-wraps-001",
        name = "Sausage, Egg & Cheese Breakfast Wraps",
        category = "Breakfast",
        description = "Freezer-friendly wholemeal breakfast burritos with lean turkey sausage, eggs, egg whites, potato, spinach and cheddar.",
        servings = 8,
        caloriesPerServing = 430.0,
        proteinPerServing = 38.0,
        carbsPerServing = 37.0,
        fatPerServing = 14.0,
        ingredients = """8 wholemeal tortillas
400 g lean turkey sausages, casings removed
8 eggs
400 g liquid egg whites
100 g reduced-fat cheddar
200 g cottage cheese
300 g potatoes
100 g spinach
Spring onions and black pepper
1 tsp olive oil""",
        method = """1. Heat oven to 200°C fan. Dice potatoes into small cubes, toss with a little oil and roast for 20–25 minutes until golden and tender.
2. Remove sausage meat from casings if needed. Brown in a large non-stick pan, breaking it into small pieces.
3. Whisk eggs and egg whites. Scramble gently in a large pan until just set.
4. Fold cottage cheese, spinach and sliced spring onions through the eggs. Season with black pepper.
5. Divide sausage, egg mixture and roasted potato evenly between eight tortillas. Add cheddar.
6. Fold tightly into burritos. Toast seam-side down in a dry pan if desired.
7. Cool promptly, wrap individually and freeze. Defrost overnight in the fridge and reheat until piping hot, or reheat from frozen using a suitable microwave/oven method.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per wrap: 430 kcal, 38 g protein, 37 g carbohydrate, 14 g fat. Sausage, tortilla and cheese brands will materially affect the final macros; verify using product labels."
    ),
    Recipe(
        id = "starter-berry-cheesecake-oats-001",
        name = "Berry Cheesecake Overnight Oats",
        category = "Breakfast",
        description = "Creamy high-protein oats with Greek yoghurt, vanilla whey, chia and mixed berries.",
        servings = 4,
        caloriesPerServing = 400.0,
        proteinPerServing = 35.0,
        carbsPerServing = 48.0,
        fatPerServing = 8.0,
        ingredients = """160 g rolled oats
400 g 0% Greek yoghurt
400 ml semi-skimmed milk
80 g vanilla whey protein
200 g mixed berries
20 g chia seeds
Vanilla extract and lemon zest""",
        method = """1. Whisk yoghurt, milk, whey and vanilla until smooth.
2. Stir in oats and chia seeds.
3. Divide between four lidded jars.
4. Top with berries and a little lemon zest.
5. Refrigerate overnight (at least 6 hours).
6. Stir before eating; add a splash of milk if too thick. Keep refrigerated and consume within 3 days.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-choc-peanut-oats-001",
        name = "Chocolate Peanut Butter Overnight Oats",
        category = "Breakfast",
        description = "Chocolate protein oats with peanut butter and banana for a filling make-ahead breakfast.",
        servings = 4,
        caloriesPerServing = 440.0,
        proteinPerServing = 36.0,
        carbsPerServing = 53.0,
        fatPerServing = 12.0,
        ingredients = """160 g rolled oats
400 g 0% Greek yoghurt
400 ml semi-skimmed milk
80 g chocolate whey protein
40 g peanut butter
2 medium bananas
10 g cocoa powder""",
        method = """1. Mix yoghurt, milk, whey and cocoa until smooth.
2. Stir in oats and divide between four jars.
3. Refrigerate overnight.
4. Before serving, top each jar with half a sliced banana and 10 g peanut butter.
5. For best texture, add banana on the morning of eating.
6. Keep refrigerated and consume within 3 days.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-apple-cinnamon-baked-oats-001",
        name = "Apple & Cinnamon Protein Baked Oats",
        category = "Breakfast",
        description = "Soft baked oatmeal squares with apple, cinnamon, Greek yoghurt and vanilla protein.",
        servings = 4,
        caloriesPerServing = 390.0,
        proteinPerServing = 32.0,
        carbsPerServing = 48.0,
        fatPerServing = 8.0,
        ingredients = """200 g rolled oats
2 eggs
300 g 0% Greek yoghurt
60 g vanilla whey protein
2 medium apples, diced
200 ml semi-skimmed milk
1 tsp baking powder
Cinnamon and vanilla extract""",
        method = """1. Heat oven to 180°C fan and line a small baking dish.
2. Mix oats, eggs, yoghurt, whey, milk, baking powder, cinnamon and vanilla.
3. Fold through diced apple, reserving a little for the top.
4. Pour into the dish and bake for 30–35 minutes until set.
5. Cool fully and cut into four squares.
6. Refrigerate for up to 3 days or freeze individually. Reheat or eat cold.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-turkey-bacon-egg-muffins-001",
        name = "Turkey Bacon & Vegetable Egg Muffins",
        category = "Breakfast",
        description = "Portable baked egg muffins with turkey bacon, spinach, peppers, cottage cheese and cheddar.",
        servings = 4,
        caloriesPerServing = 330.0,
        proteinPerServing = 35.0,
        carbsPerServing = 8.0,
        fatPerServing = 17.0,
        ingredients = """8 eggs
300 g liquid egg whites
200 g lean turkey bacon
100 g reduced-fat cheddar
1 pepper
100 g spinach
100 g cottage cheese
Spring onions and black pepper""",
        method = """1. Heat oven to 180°C fan. Lightly oil a 12-hole muffin tin.
2. Cook turkey bacon in a pan and chop into small pieces.
3. Whisk eggs, egg whites and cottage cheese. Stir in chopped pepper, spinach, spring onion and bacon.
4. Divide between 12 muffin holes and sprinkle with cheddar.
5. Bake for 18–22 minutes until fully set.
6. Three muffins make one of four portions. Refrigerate up to 3 days or freeze once cooled.""",
        freezerFriendly = true,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-lemongrass-chicken-001",
        name = "Vietnamese Lemongrass Chicken Bowls",
        category = "Dinner",
        description = "Fragrant lemongrass chicken with jasmine rice, edamame, crunchy vegetables, mint and coriander.",
        servings = 4,
        caloriesPerServing = 510.0,
        proteinPerServing = 49.0,
        carbsPerServing = 55.0,
        fatPerServing = 9.0,
        ingredients = """700 g chicken breast
200 g jasmine rice (dry)
2 lemongrass stalks, finely chopped
150 g shelled edamame
2 carrots
½ cucumber
30 ml fish sauce
20 g honey
2 garlic cloves
20 g ginger
2 limes
Mint and coriander""",
        method = """1. Pound or finely chop the tender inner lemongrass. Mix with fish sauce, honey, garlic, ginger and lime juice.
2. Slice chicken and marinate for at least 20 minutes.
3. Cook rice. Stir-fry or grill chicken until cooked through and lightly caramelised.
4. Cook edamame. Julienne carrots and cucumber.
5. Divide rice, chicken and edamame between four bowls. Add vegetables and herbs.
6. Store crunchy vegetables separately and add after reheating.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-pork-souvlaki-001",
        name = "Greek Pork Souvlaki Bowls",
        category = "Dinner",
        description = "Lemon-oregano pork with roasted potato wedges, Greek salad and homemade tzatziki.",
        servings = 4,
        caloriesPerServing = 530.0,
        proteinPerServing = 47.0,
        carbsPerServing = 48.0,
        fatPerServing = 16.0,
        ingredients = """700 g lean pork loin
800 g potatoes
200 g 0% Greek yoghurt
½ cucumber
200 g tomatoes
½ red onion
1 lemon
2 tsp dried oregano
2 garlic cloves
1 tsp smoked paprika""",
        method = """1. Heat oven to 200°C fan. Cut potatoes into wedges, season and roast for 30–35 minutes, turning once.
2. Dice pork. Toss with lemon juice, oregano, paprika, garlic, salt and pepper.
3. Grill or pan-fry pork until browned and cooked through; rest briefly.
4. Grate cucumber, squeeze out excess liquid and mix with yoghurt, garlic and lemon to make tzatziki.
5. Serve pork with potatoes, chopped tomato, onion and tzatziki.
6. Keep tzatziki and salad separate from hot components for meal prep.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-tandoori-salmon-001",
        name = "Tandoori Salmon Bowls",
        category = "Dinner",
        description = "Yoghurt-marinated tandoori salmon with basmati rice, cucumber, tomatoes and mint yoghurt.",
        servings = 4,
        caloriesPerServing = 550.0,
        proteinPerServing = 43.0,
        carbsPerServing = 48.0,
        fatPerServing = 20.0,
        ingredients = """600 g salmon fillets
200 g basmati rice (dry)
200 g 0% Greek yoghurt
1 cucumber
200 g cherry tomatoes
1 lemon
Tandoori spice blend
1 garlic clove
Fresh ginger and mint""",
        method = """1. Heat oven to 200°C fan.
2. Mix half the yoghurt with tandoori seasoning, grated garlic, ginger and lemon zest. Coat salmon and marinate for 15–30 minutes.
3. Bake salmon for 12–15 minutes, depending on thickness, until cooked to preference.
4. Cook basmati rice. Mix remaining yoghurt with chopped mint and lemon juice.
5. Serve salmon with rice, cucumber and tomatoes; add mint yoghurt.
6. Keep yoghurt and salad separate. Refrigerate promptly; freezing cooked salmon may soften its texture.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-moroccan-lamb-kofta-001",
        name = "Moroccan Lamb Kofta Bowls",
        category = "Dinner",
        description = "Spiced lamb koftas with couscous, roasted vegetables, yoghurt and a small hummus portion.",
        servings = 4,
        caloriesPerServing = 560.0,
        proteinPerServing = 44.0,
        carbsPerServing = 48.0,
        fatPerServing = 20.0,
        ingredients = """600 g lean lamb mince
200 g couscous (dry)
200 g 0% Greek yoghurt
40 g hummus
1 red pepper
1 courgette
1 red onion
Cumin, ground coriander, cinnamon and paprika
2 garlic cloves
Parsley and lemon""",
        method = """1. Heat oven to 200°C fan. Chop pepper, courgette and onion; roast until tender.
2. Mix lamb with cumin, coriander, cinnamon, paprika, garlic and parsley.
3. Shape into 12 koftas and bake or grill until cooked through.
4. Prepare couscous according to packet instructions and fluff with lemon juice.
5. Divide couscous, vegetables and koftas between four bowls.
6. Serve with yoghurt and 10 g hummus per portion. Keep yoghurt separate for meal prep.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    ),
    Recipe(
        id = "starter-chicken-katsu-001",
        name = "Lighter Chicken Katsu Curry",
        category = "Dinner",
        description = "Oven-crisp panko chicken with a Japanese-style carrot and onion curry sauce and rice.",
        servings = 4,
        caloriesPerServing = 560.0,
        proteinPerServing = 48.0,
        carbsPerServing = 65.0,
        fatPerServing = 10.0,
        ingredients = """700 g chicken breast
200 g basmati rice (dry)
60 g panko breadcrumbs
1 egg
1 onion
2 carrots
500 ml chicken stock
30 g Japanese curry roux
10 g cornflour
Garlic and ginger""",
        method = """1. Heat oven to 200°C fan. Slice chicken breasts horizontally into even fillets.
2. Dip chicken in beaten egg, then coat in panko. Place on a wire rack over a tray and bake until golden and the thickest part reaches 75°C.
3. Cook rice separately.
4. Simmer finely chopped onion and grated carrot in chicken stock until soft.
5. Stir in curry roux until dissolved. Mix cornflour with cold water and add gradually to reach a coating consistency.
6. Slice chicken and serve over rice with curry sauce.
7. Keep chicken separate from sauce for best crispness; reheat chicken in an oven or air fryer.""",
        freezerFriendly = false,
        nutritionNote = "Planning estimate per serving. Actual macros depend on ingredient brands, trimming, cooking yield and portion weights; verify against product labels before treating as exact."
    )
)

@Composable
fun RecipesScreen(dao: RepForgeDao, recipes: List<Recipe>, today: String, notify: (String) -> Unit) {
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        ScreenTitle("Build your rotation", "Recipes.")
        Text("STARTER RECIPES", color = Electric, fontSize = 10.sp, letterSpacing = 1.5.sp, fontWeight = FontWeight.Bold)
        Text("Batch-cook favourites with serving-level nutrition.", color = Muted, fontSize = 12.sp, modifier = Modifier.padding(bottom = 12.dp))
        if (recipes.isEmpty()) {
            PanelCard { Text("Your recipe library is empty.", color = Muted) }
        }
        recipes.forEach { recipe ->
            var expanded by remember(recipe.id) { mutableStateOf(false) }
            PanelCard {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                    Column(Modifier.weight(1f)) {
                        Text(recipe.category.uppercase(), color = Electric, fontSize = 10.sp, letterSpacing = 1.sp)
                        Text(recipe.name, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                        Text(recipe.description, color = Muted, fontSize = 11.sp)
                    }
                    if (recipe.freezerFriendly) Text("FREEZER", color = Green, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(12.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column { Text("${recipe.caloriesPerServing.toInt()} kcal", fontSize = 20.sp, fontWeight = FontWeight.Bold); Text("per serving", color = Muted, fontSize = 10.sp) }
                    Column(horizontalAlignment = Alignment.End) { Text("${recipe.proteinPerServing.toInt()} g protein", color = Green, fontWeight = FontWeight.SemiBold); Text("${recipe.servings} batch servings", color = Muted, fontSize = 10.sp) }
                }
                Text("C ${recipe.carbsPerServing.toInt()} g  ·  F ${recipe.fatPerServing.toInt()} g", color = Muted, fontSize = 11.sp)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { expanded = !expanded }, modifier = Modifier.weight(1f)) {
                        Text(if (expanded) "Hide recipe" else "Ingredients & method")
                    }
                    Button(onClick = {
                        scope.launch {
                            dao.insertFood(NutritionEntry(
                                date = today, meal = if (recipe.category == "Breakfast") "Breakfast" else if (recipe.category == "Lunch") "Lunch" else "Dinner",
                                name = recipe.name, calories = recipe.caloriesPerServing, protein = recipe.proteinPerServing,
                                carbs = recipe.carbsPerServing, fat = recipe.fatPerServing,
                                servingNote = "1 serving from ${recipe.servings}-serving batch"
                            ))
                            notify("${recipe.name} added to today's diary")
                        }
                    }, modifier = Modifier.weight(1f)) { Text("Log serving") }
                }
                if (expanded) {
                    HorizontalDivider(color = Border, modifier = Modifier.padding(vertical = 10.dp))
                    Text("INGREDIENTS", color = Electric, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                    Text(recipe.ingredients, fontSize = 12.sp, lineHeight = 18.sp, modifier = Modifier.padding(top = 5.dp))
                    Spacer(Modifier.height(12.dp))
                    Text("METHOD", color = Electric, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                    Text(recipe.method, fontSize = 12.sp, lineHeight = 18.sp, modifier = Modifier.padding(top = 5.dp))
                    Spacer(Modifier.height(8.dp))
                    Text(recipe.nutritionNote, color = Muted, fontSize = 10.sp, lineHeight = 14.sp)
                }
            }
        }
        Spacer(Modifier.height(20.dp))
    }
}

@Composable fun TrainingScreen(dao:RepForgeDao,templates:List<WorkoutTemplate>,logs:List<WorkoutLog>,notify:(String)->Unit) {
    var programme by remember { mutableStateOf("My programme") }; var workout by remember { mutableStateOf("Full Body A") }; var exerciseText by remember { mutableStateOf("Squat|3|5\nBench press|3|5\nBarbell row|3|8") }
    var selected by remember { mutableStateOf<Long?>(null) }; var weights by remember { mutableStateOf(mapOf<String,String>()) }; var notes by remember { mutableStateOf("") }
    val scope=rememberCoroutineScope(); val template=templates.firstOrNull{it.id==selected}?:templates.firstOrNull()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        ScreenTitle("Progressive overload","Training.")
        PanelCard {
            Text("PROGRAMME BUILDER",color=Muted,fontSize=10.sp,letterSpacing=1.sp)
            OutlinedTextField(programme,{programme=it},label={Text("Programme name")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            OutlinedTextField(workout,{workout=it},label={Text("Workout name")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            OutlinedTextField(exerciseText,{exerciseText=it},label={Text("Exercises: one per line — Name | sets | reps")},modifier=Modifier.fillMaxWidth().heightIn(min=120.dp),minLines=3)
            Text("Example: Squat | 3 | 5",color=Muted,fontSize=10.sp)
            Button(onClick={val cleaned=exerciseText.lines().mapNotNull { line -> val parts=line.split("|").map{it.trim()}; if(parts[0].isBlank())null else "${parts[0]}|${parts.getOrNull(1)?.toIntOrNull()?.coerceIn(1,20)?:3}|${parts.getOrNull(2)?.toIntOrNull()?.coerceIn(1,100)?:8}" };if(cleaned.isEmpty())notify("Add at least one exercise")else scope.launch{dao.insertTemplate(WorkoutTemplate(programmeName=programme,workoutName=workout,exercises=cleaned.joinToString("\n")));notify("Workout template saved")}},modifier=Modifier.fillMaxWidth()){Text("Save workout template")}
        }
        PanelCard {
            Text("START SESSION",color=Muted,fontSize=10.sp,letterSpacing=1.sp)
            if(templates.isEmpty()) Text("Save a workout template to begin.",color=Muted) else {
                templates.forEach { t -> Row(verticalAlignment=Alignment.CenterVertically) { RadioButton(selected=(template?.id==t.id),onClick={selected=t.id}); Column { Text("${t.programmeName} · ${t.workoutName}",fontWeight=FontWeight.SemiBold); Text(t.exercises.lines().joinToString(" · "){it.substringBefore("|")},fontSize=11.sp,color=Muted) } } }
                template?.let { t ->
                    Spacer(Modifier.height(8.dp)); Text("Record working sets",fontWeight=FontWeight.SemiBold)
                    t.exercises.lines().forEachIndexed { index,line ->
                        val p=line.split("|"); val ex=p[0]; val sets=p.getOrNull(1)?.toIntOrNull()?:3; val reps=p.getOrNull(2)?.toIntOrNull()?:8
                        Text("$ex · $sets × $reps",color=Electric,fontWeight=FontWeight.Medium,modifier=Modifier.padding(top=8.dp))
                        repeat(sets) { set -> val key="$index-$set"; OutlinedTextField(weights[key]?: "",{weights=weights+(key to it)},label={Text("Set ${set+1} weight (kg)")},modifier=Modifier.fillMaxWidth(),singleLine=true) }
                    }
                    OutlinedTextField(notes,{notes=it},label={Text("Session notes (optional)")},modifier=Modifier.fillMaxWidth())
                    Button(onClick={val summary=t.exercises.lines().mapIndexed { i,l -> val p=l.split("|"); "${p[0]}: "+(0 until (p.getOrNull(1)?.toIntOrNull()?:3)).joinToString(", ") { s -> "${weights["$i-$s"].orEmpty().ifBlank{"—"} } kg × ${p.getOrNull(2)?:8}" } }.joinToString("; ");scope.launch{dao.insertWorkout(WorkoutLog(date=LocalDate.now().toString(),workoutName=t.workoutName,exerciseSummary=summary,completedSets=weights.count{it.value.isNotBlank()},notes=notes));weights=emptyMap();notes="";notify("Workout saved to history")}},modifier=Modifier.fillMaxWidth()){Text("Finish and save workout")}
                }
            }
        }
        PanelCard { Text("WORKOUT HISTORY",fontWeight=FontWeight.SemiBold); if(logs.isEmpty())Text("Your sessions will appear here.",color=Muted) else logs.forEach { l -> HorizontalDivider(color=Border); Spacer(Modifier.height(8.dp)); Text("${l.date} · ${l.workoutName}",fontWeight=FontWeight.SemiBold); Text("${l.completedSets} sets with weights recorded",color=Muted,fontSize=11.sp); Text(l.exerciseSummary,fontSize=12.sp); if(l.notes.isNotBlank())Text(l.notes,color=Muted,fontSize=11.sp) } }
        Spacer(Modifier.height(20.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ProgressScreen(dao:RepForgeDao,measurements:List<MeasurementEntry>,notify:(String)->Unit) {
    var date by remember { mutableStateOf(LocalDate.now().toString()) }; var weight by remember { mutableStateOf("") }; var notes by remember { mutableStateOf("") }
    val fields=listOf("Neck (cm)","Chest (cm)","Waist (cm)","Hips (cm)","Right thigh (cm)","Left thigh (cm)","Right calf (cm)","Left calf (cm)","Right biceps (cm)","Left biceps (cm)","Right forearm (cm)","Left forearm (cm)")
    var values by remember { mutableStateOf(List(12){""}) }; var metric by remember { mutableStateOf("Weight (kg)") }
    val scope=rememberCoroutineScope()
    val metricValues:List<Pair<String,Double>> = when(metric) {
        "Weight (kg)" -> measurements.mapNotNull{m->m.weightKg?.let{m.date to it}}
        "Waist (cm)" -> measurements.mapNotNull{m->m.waistCm?.let{m.date to it}}
        "Chest (cm)" -> measurements.mapNotNull{m->m.chestCm?.let{m.date to it}}
        "Hips (cm)" -> measurements.mapNotNull{m->m.hipsCm?.let{m.date to it}}
        "Neck (cm)" -> measurements.mapNotNull{m->m.neckCm?.let{m.date to it}}
        "Right thigh (cm)" -> measurements.mapNotNull{m->m.thighRightCm?.let{m.date to it}}
        "Left thigh (cm)" -> measurements.mapNotNull{m->m.thighLeftCm?.let{m.date to it}}
        "Right calf (cm)" -> measurements.mapNotNull{m->m.calfRightCm?.let{m.date to it}}
        "Left calf (cm)" -> measurements.mapNotNull{m->m.calfLeftCm?.let{m.date to it}}
        "Right biceps (cm)" -> measurements.mapNotNull{m->m.bicepsRightCm?.let{m.date to it}}
        "Left biceps (cm)" -> measurements.mapNotNull{m->m.bicepsLeftCm?.let{m.date to it}}
        "Right forearm (cm)" -> measurements.mapNotNull{m->m.forearmRightCm?.let{m.date to it}}
        else -> measurements.mapNotNull{m->m.forearmLeftCm?.let{m.date to it}}
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        ScreenTitle("Measure what matters","Progress.")
        PanelCard {
            Text("LOG MEASUREMENTS",color=Muted,fontSize=10.sp,letterSpacing=1.sp)
            OutlinedTextField(date,{date=it},label={Text("Date (YYYY-MM-DD)")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            OutlinedTextField(weight,{weight=it},label={Text("Weight (kg)")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            fields.forEachIndexed { i, label -> OutlinedTextField(values[i],{v->values=values.toMutableList().also{it[i]=v}},label={Text(label)},modifier=Modifier.fillMaxWidth(),singleLine=true) }
            OutlinedTextField(notes,{notes=it},label={Text("Notes")},modifier=Modifier.fillMaxWidth())
            Button(onClick={val parsed=values.map{it.toDoubleOrNull()};if(weight.isBlank()&&parsed.all{it==null})notify("Enter at least one measurement")else scope.launch{dao.insertMeasurement(MeasurementEntry(date=date,weightKg=weight.toDoubleOrNull(),neckCm=parsed[0],chestCm=parsed[1],waistCm=parsed[2],hipsCm=parsed[3],thighRightCm=parsed[4],thighLeftCm=parsed[5],calfRightCm=parsed[6],calfLeftCm=parsed[7],bicepsRightCm=parsed[8],bicepsLeftCm=parsed[9],forearmRightCm=parsed[10],forearmLeftCm=parsed[11],notes=notes));weight="";values=List(12){""};notes="";notify("Measurements saved")}},modifier=Modifier.fillMaxWidth()){Text("Save measurements")}
        }
        PanelCard {
            Text("TREND CHART",fontWeight=FontWeight.SemiBold)
            var expanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}) {
                OutlinedTextField(value=metric, onValueChange={}, label={Text("Metric")}, modifier=Modifier.fillMaxWidth().menuAnchor(), readOnly=true, trailingIcon={ExposedDropdownMenuDefaults.TrailingIcon(expanded)})
                ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) { listOf("Weight (kg)","Neck (cm)","Chest (cm)","Waist (cm)","Hips (cm)","Right thigh (cm)","Left thigh (cm)","Right calf (cm)","Left calf (cm)","Right biceps (cm)","Left biceps (cm)","Right forearm (cm)","Left forearm (cm)").forEach { DropdownMenuItem(text={Text(it)},onClick={metric=it;expanded=false}) } }
            }
            Spacer(Modifier.height(12.dp))
            if(metricValues.isEmpty()) Text("Add measurements to build this trend.",color=Muted) else {
                val vals=metricValues.map{it.second}; val min=vals.minOrNull()!!; val max=vals.maxOrNull()!!; val span=(max-min).takeIf{it>0}?:1.0
                Canvas(Modifier.fillMaxWidth().height(190.dp)) {
                    val left=28f; val right=size.width-8f; val top=10f; val bottom=size.height-24f
                    repeat(5){i->val y=top+(bottom-top)*i/4;drawLine(Border,Offset(left,y),Offset(right,y),1f)}
                    val pts=vals.mapIndexed{i,v->Offset(if(vals.size==1)(left+right)/2 else left+(right-left)*i/(vals.size-1),bottom-((v-min)/span).toFloat()*(bottom-top))}
                    pts.zipWithNext().forEach{(a,b)->drawLine(Electric,a,b,3f,cap=StrokeCap.Round)}
                    pts.forEach{drawCircle(Electric,4f,it)}
                }
                Text("${metricValues.first().first} → ${metricValues.last().first} · ${metricValues.size} entries · ${min}–${max}",fontSize=10.sp,color=Muted)
            }
        }
        PanelCard { Text("HISTORY",fontWeight=FontWeight.SemiBold); if(measurements.isEmpty()) Text("No measurements logged.",color=Muted) else measurements.asReversed().forEach { m -> Row(Modifier.fillMaxWidth().padding(vertical=7.dp),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(m.date,fontWeight=FontWeight.SemiBold); Text(listOfNotNull(m.weightKg?.let{"${it} kg"},m.waistCm?.let{"waist ${it} cm"},m.chestCm?.let{"chest ${it} cm"}).joinToString(" · "),fontSize=11.sp,color=Muted); if(m.notes.isNotBlank())Text(m.notes,fontSize=11.sp,color=Muted) }; TextButton(onClick={scope.launch{dao.deleteMeasurement(m.id)}}){Text("Delete",color=Color(0xFFFF6D7A))} }; HorizontalDivider(color=Border) } }
        Spacer(Modifier.height(20.dp))
    }
}

@Composable fun SettingsScreen(calories:String,onCalories:(String)->Unit,protein:String,onProtein:(String)->Unit,carbs:String,onCarbs:(String)->Unit,fat:String,onFat:(String)->Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        ScreenTitle("Your baseline","Settings.")
        PanelCard {
            Text("DAILY TARGETS",color=Muted,fontSize=10.sp,letterSpacing=1.sp)
            OutlinedTextField(calories,onCalories,label={Text("Calories (kcal)")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            OutlinedTextField(protein,onProtein,label={Text("Protein (g)")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            OutlinedTextField(carbs,onCarbs,label={Text("Carbohydrates (g)")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            OutlinedTextField(fat,onFat,label={Text("Fat (g)")},modifier=Modifier.fillMaxWidth(),singleLine=true)
            Text("Targets are editable during this session. Persistent target settings and nutrition recommendations are planned for the next iteration.",fontSize=11.sp,color=Muted)
        }
        PanelCard {
            Text("LOCAL-FIRST STORAGE",fontWeight=FontWeight.SemiBold)
            Text("Food entries, workouts, templates and measurements are saved in an on-device Room database. This native prototype does not yet provide account sign-in, cloud sync or backup/export.",color=Muted,fontSize=12.sp)
            Spacer(Modifier.height(8.dp)); Text("RepForge Android · v0.1.0",color=Electric,fontSize=11.sp)
        }
    }
}
