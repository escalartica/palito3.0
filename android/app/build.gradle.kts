import java.io.FileInputStream
import java.util.Properties

// ══ LA FIRMA DE RELEASE ══
//
// Las credenciales del almacén viven en android/key.properties, que NO está
// en git (lo ignora android/.gitignore, igual que cualquier *.jks). Este
// fichero solo sabe leerlas; no contiene ni una contraseña.
//
// Si el fichero no existe —otro ordenador, o alguien recién clonado el
// repositorio— la compilación NO se rompe: cae a la clave de depuración, con
// lo que `flutter run --release` sigue funcionando para probar. Lo que no se
// puede es subir eso a Play, y por eso el `if` de más abajo es explícito en
// vez de silencioso.

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hayAlmacen = keystorePropertiesFile.exists()
if (hayAlmacen) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.palito.sabores"
    compileSdk = flutter.compileSdkVersion
    // ══ POR QUÉ ESTA LÍNEA ESTÁ COMENTADA ══
    //
    // La traía la plantilla de Flutter. Declarar `ndkVersion` obliga a Gradle
    // a resolver el NDK —el compilador de C/C++ de Android— ANTES de configurar
    // nada, y si la carpeta no está buena aborta con `[CXX1101] ... did not
    // have a source.properties file`, que fue exactamente lo que pasó el 20/09
    // después de que un disco lleno dejara ahí una carpeta vacía de 4 KB.
    //
    // Esta app no tiene una sola línea de C ni de C++. Los plugins que usa
    // (Firebase, geolocator, image_picker, flutter_map) vienen con sus
    // bibliotecas nativas YA compiladas dentro del paquete: nadie las vuelve a
    // compilar aquí, así que el NDK no pinta nada. Descargarlo son más de 2 GB
    // para no usarlo.
    //
    // Si algún día se añade un plugin con código nativo de verdad, Gradle lo
    // dirá con un error claro y entonces se descomenta.
    //
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ══ ESTO NO SE PUEDE CAMBIAR DESPUÉS ══
        //
        // Venía como "com.example.palito_3_0", el marcador de posición de la
        // plantilla de Flutter. Google Play rechaza de plano cualquier
        // `com.example.*`, así que nunca habría llegado a publicarse.
        //
        // Se pone el mismo que en iOS para que la app tenga una sola
        // identidad en las dos tiendas. Y va en mayúsculas el aviso porque en
        // Android el applicationId queda fijado en la primera publicación:
        // cambiarlo después significa una app nueva, sin las descargas ni las
        // reseñas de la anterior.
        applicationId = "com.palito.sabores"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayAlmacen) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // Ruta relativa a android/app/, que es donde vive el .jks.
                storeFile = (keystoreProperties["storeFile"] as String).let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Antes firmaba con la clave de DEPURACIÓN —venia así de la
            // plantilla, con su TODO sin hacer—. Play rechaza cualquier
            // paquete firmado con ella, así que la subida habría fallado en el
            // último paso, después de compilar.
            signingConfig = if (hayAlmacen) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
