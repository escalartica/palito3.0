allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// ══ TODOS LOS MÓDULOS COMPILAN CONTRA UNA VERSIÓN MODERNA DE ANDROID ══
//
// EL PROBLEMA. Cada plugin de Flutter trae su propio `compileSdk` escrito a
// mano dentro del paquete. `geocoding_android` dice 33, y sus propias
// dependencias de AndroidX exigen 34 o más, así que la compilación se para con
// quince quejas seguidas del tipo:
//
//     Dependency 'androidx.fragment:fragment:1.7.1' requires libraries and
//     applications that depend on it to compile against version 34 or later
//     ... :geocoding_android is currently compiled against android-33.
//
// POR QUÉ NO SE ARREGLA SUBIENDO EL PLUGIN. Se podría subir `geocoding`, sí,
// pero el problema no es de ese paquete: lo tiene cualquier plugin que lleve un
// tiempo sin tocarse, y la app usa una docena. Arreglarlos de uno en uno
// significa descubrir el siguiente después de otros siete minutos de
// compilación, y volver a empezar cada vez que se añada una dependencia.
//
// QUÉ HACE. Sobreescribe el `compileSdk` de cada módulo a 36. `compileSdk` es
// solo **contra qué APIs se compila**; no cambia `minSdk` (qué móviles pueden
// instalar la app) ni `targetSdk` (qué comportamientos nuevos del sistema
// acepta). Es exactamente lo que recomienda el mensaje de error de Android.
//
// ══ POR QUÉ ESTE BLOQUE VA AQUÍ ARRIBA Y NO MÁS ABAJO ══
//
// El bloque siguiente llama a `evaluationDependsOn(":app")`, que obliga a
// Gradle a evaluar `:app` en ese mismo instante. Puesto después, este código se
// encontraba `:app` ya evaluado y Gradle lo rechazaba en seco:
//
//     Cannot run Project.afterEvaluate(Action) when the project is already
//     evaluated.
//
// Y aunque no diera error, llegaría tarde: para entonces el plugin de Android
// ya habría leído el `compileSdk` viejo. El orden de estos dos bloques no es
// estético, es lo que hace que funcione. La comprobación de `state.executed`
// está por si alguien los reordena: entonces al menos se aplica en el acto en
// vez de reventar.
//
// ══ POR QUÉ POR REFLEXIÓN Y NO ESCRIBIENDO `android.compileSdk = 36` ══
//
// Este proyecto va con el plugin de Android 9.0.1, que ha movido y renombrado
// buena parte de su DSL. Nombrar la clase directamente ataría este fichero a
// una versión concreta y lo rompería en la siguiente actualización — el tipo de
// avería que aparece meses después y nadie relaciona con este cambio. Buscando
// el método se aguanta en las dos.
val sdkDeCompilacion = 36

fun fijarCompileSdk(proyecto: Project) {
    val android = proyecto.extensions.findByName("android") ?: return

    val aplicado =
        listOf<Pair<String, Class<*>?>>(
            "setCompileSdk" to Integer::class.java,
            "compileSdkVersion" to Int::class.javaPrimitiveType,
        ).any { (nombre, tipo) ->
            val metodo =
                android.javaClass.methods.firstOrNull {
                    it.name == nombre &&
                        it.parameterTypes.size == 1 &&
                        it.parameterTypes[0] == tipo
                }
            if (metodo == null) {
                false
            } else {
                metodo.invoke(android, sdkDeCompilacion)
                true
            }
        }

    if (!aplicado) {
        // Sin aviso, esto fallaría en silencio y la compilación volvería a
        // romperse con el error de AndroidX sin pista de por qué.
        proyecto.logger.warn(
            "No se pudo fijar compileSdk=$sdkDeCompilacion en ${proyecto.path}: " +
                "el plugin de Android ha cambiado su API. Mira el comentario de " +
                "android/build.gradle.kts.",
        )
    }
}

subprojects {
    if (state.executed) {
        fijarCompileSdk(this)
    } else {
        afterEvaluate { fijarCompileSdk(this) }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
