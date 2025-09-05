@echo off
echo Starting optimized Flutter build for mobile...

REM Clean and restart Gradle daemon
echo Stopping Gradle daemons...
cd android
call gradlew --stop
cd ..

REM Set optimized environment variables
set GRADLE_OPTS=-Xmx4g -XX:MaxMetaspaceSize=2g
set JAVA_TOOL_OPTIONS=-Xmx4g

echo Building for Android device...
flutter run -d I2306 --debug --fast-start --dart-define=flutter.inspector.structuredErrors=false

pause