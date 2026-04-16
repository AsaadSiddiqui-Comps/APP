build/app/outputs/flutter-apk/app-debug.apk


ok all things are proepr 
now you have to fix first that auto feature in that it will crop as per the edge dection use best package for that 
after corping it will give the acess to draw the corner as per the image i haev hsahr dragcorners to customize it
Add actual manual crop handles (drag corners) like your reference UI
Add persistent local storage for drafts (survive app restart).

and after saving it to draft like clikc on save to draft then it will redirect back to the home page with savingthe the draft file 
mak the stroage also like it will sue on deivce storage make one folder with the app name only in two folder one called draft and one called exported means in that iy will be like exporting pdf text much more fileso n that only

implement filter more differnet fast and optimize manner change the ui for filter make some intresting and also add much more logics to it to make it more better and survive in all cases like user is doing this then what  like that all condditions


You have to now appyl fixings
fist on auto crop the dragable croping is like opening screen full mode which is inconsistent i want that when i will clikc on it it will be like loads and then active bar then on that only it will show the croping option like no screen change all things on same screen
on auto mode it will be doing more things if user click the auto mode again then it will remove the all auto feature did make suer that you have to make it proeprly

now other thing like filter when the filter button clikc it will not open a menu it will open one strip in that page only 
and on that add one non option which implies that no change it will be active at first and then if user click on any other filter then that card  will active , make it like a smal preview also and also make this smooth preprocessing so when change so no lag or delay will be their

Add true 4-point perspective warp for manual crop handles.
use opne cv also it will like best for filter and croping it handle smooth i think you can combine it with ml kit too.
opencv_dart: ^2.2.1+4

the app perfomace is slithly low bez their is no aniamtion and transition at all the app is in low state , we want optimzed one with better feedback delever to it

also dont make that code become inconsistent make it proepr structured way not that all things in one we have to make bet and better app with good performance and best feature deal



NOw lets implement the Saving option 
first more that save as draft to the editor top 3 dot menu
and if your like try to go bakc then it will poup that dscard or save as draft
discord means it will go to the home screen without sve it draft also adn if sve as draft it will be save a draft and back to the home screen with saving the draft

now on blow you have to add one button done in the palce of save as draft
it will redriect to he next screen
now in next screen it will ve below on button save to ..
blviking on it will open menu
save to device ->
Export to ... ->

-- section break --
[icon]Add watermark
[icon]add digital signature
[icon]rename 
[icon]print
[icon]delete

when user clicks save to device
on save to device it will direclty open a mobile file exploler adn user will chose the destination that where to save
when destination choosed now it will direclty export that document in to pdf format in to that specific destination it will show the progress bar

Export to 
then it will open one menue in that itwill show exporting options that all pdf or images if images slelected then all images taken wil be exported in image format only sepratly and if pdf then it will make one full pdfwhich contains all photos

forte nm=ow make this only we will be implmeneting more thing soon as per the progress we are doing 
make sure to optimzed lag free


THINGS TO FIX
first make the background preprocessin to the image taken so all thing wil be fast and optimzed its laggin now for this 
the rotating viusal will be shown os it will better by cliking to much time and it is also laggin to to rotate so we need to fix this
improe the crop dragable dorping propelr it lagging 


Things you have to fix first
implement the cropping tool more better that the draging selector is lagging we want it smooth as fast as can like normal cropping done too fast but here it selector is to much laggy and when the cornner we holded on that it will show the samml preview also like  a modern terms do for editing like when we hold the coder o we cant able to see that till where we have to stop
and make the selector tool more better it will have more 4 center of the line to strech it or long both

second hing 
is that when i click on rotate it will show the viusal cards of option active like filter from that user cna choose any , previent by cliking agianga and agian to rotate it
adn disbale the toast notifiantion of rotte operation

now on after done export setting here all options are givne so the that you have make that dsave to.. with export (estmatied size ( in mb))
 and when export button cliked it wil export it 

 now you have to install that pdfinum package whic wil make the pdf pile exproting process proerply or use best package sdk for this pdf operation more better 
 in now stage it is show export fails try again i think oyu have not implemented that  
 see fix it make it mcuh better
 optimized better performance


problems are their
🧾 issue fix 1 — Change storage to accessible internal storage
currently my files are being saved in the internal app directory (/data/user/0/<package>/app_flutter/), which is not accessible through the device file manager. I want to modify my code so that files are instead saved in a user-accessible location like /storage/emulated/0/Documents/Docly/ (this wil be defualt location of app) or a similar public directory. Please provide a clean and modern Flutter solution using path_provider or any recommended approach that ensures compatibility with newer Android versions (Android 11+), including proper handling of storage restrictions.

🧾 issue fix 2— Fix “directory not writable” issue
In my Flutter app, when I try to create or use a custom directory in internal storage like /storage/emulated/0/Documents/Docly/, I sometimes get errors saying the directory is not writable. I want to properly fix this issue by handling permissions correctly across Android versions (especially Android 13+). Please explain how to request and manage runtime storage permissions using packages like permission_handler, and how to ensure the directory is created and writable without errors.

🧾 iisue 3 fix — Make files visible in Samsung File Manager
I want my Flutter app to save files in a location that is easily accessible through Samsung’s default file manager (My Files app), without needing ADB or root access. The files should appear normally under categories like Documents or Downloads. Please suggest the best directory path and implementation strategy to ensure files are visible and persistent, and explain any Android storage policies (like scoped storage) that I need to handle properly.


ah its still saving the files in the /data/user/0/<package>/app_flutter/ the choosen folder is not write able and if i have not seelected any then i dontknow here it save the file 

so i want just two things
that first the app should create one custom folder here  /storage/emulated/0/Documents/Docly/
and here inside it should save the draft and exported files {pdf/images}
second is let user select the destination folder at that it donest show the that folder is not writeable, as per user specific 

we are using Android verison 11+


it is saving the files here 
/sdcard/Android/data/com.pixeldev.Docly/files/Docly/exported
so one thing is fixed 

now the next issue is still remianig that whne choosing custom folder 
first it show the selected fodler is inaccessible and saved to  this /sdcard/Android/data/com.pixeldev.Docly/files/Docly/exported

so i have think this that 
we have two buttons one save to.. and one export

so change this save to.. = {icon} share


and remove he save as menue  and the destination will be fixed to app defualt storage, it will export it on this location only 
/sdcard/Android/data/com.pixeldev.Docly/files/Docly/exported

but now let make this that all pdf is exproted on this path just now we have to make that the pdf can be accessable from recent files so  or make it that like normal browser downlado the files on download folder so just you have to make that it will epxort it on downlaod folder by defualt so it will be proepr and accesable path from mobile

the thing is /sdcard/Android/data/com.pixeldev.Docly/files/Docly/exported
 this path is nto accessble by mobile bez of security in android 14+ so we have to make it proepr that it should export it to downlaod

Searhc ofr better solution


The application is currently experiencing UI freezes, delayed responses, and ANR-like behavior because all heavy image processing operations (crop, rotate, filters, resize, and PDF generation) are executed on the main UI isolate. This blocks rendering and interaction. The correct approach is to restructure the entire image-processing pipeline into a non-blocking, multi-stage system that separates preview rendering from final high-resolution processing while offloading all CPU-intensive work to background isolates.

Start by introducing a unified processing pipeline that follows this flow: user action → instant UI feedback → low-resolution preview processing → background high-resolution processing → UI update. Every feature (crop, rotate, filters, export) must plug into this same pipeline.

For crop operations, the lag occurs because the crop is applied only after pressing “Apply” and is processed synchronously. Instead, render the crop visually using an overlay (no processing yet), and only finalize the crop in a background isolate when the user confirms. The UI must respond instantly while the actual crop computation happens asynchronously.

```dart
Uint8List cropImage(Uint8List bytes) {
  final img = decodeImage(bytes)!;
  final cropped = copyCrop(img, x: 0, y: 0, width: 500, height: 500);
  return Uint8List.fromList(encodeJpg(cropped));
}

// usage
final result = await compute(cropImage, originalBytes);
```

For rotation, the delay comes from performing pixel transformations on large images on the main thread. Move rotation into an isolate and immediately reflect the change visually (e.g., temporary transform in UI), then replace with processed output once complete.

```dart
Uint8List rotateImage(Uint8List bytes) {
  final img = decodeImage(bytes)!;
  final rotated = copyRotate(img, 90);
  return Uint8List.fromList(encodeJpg(rotated));
}
```

For filters, the major issue is applying effects on full-resolution images. This must be split into two stages: preview and final. Generate a low-resolution version (e.g., width: 600px) for instant filter previews, and only apply the selected filter to the full-resolution image in the background when confirmed or during export.

```dart
Uint8List applyFilterPreview(Uint8List bytes) {
  final img = decodeImage(bytes)!;
  final small = copyResize(img, width: 600);
  final gray = grayscale(small);
  return Uint8List.fromList(encodeJpg(gray));
}

Uint8List applyFilterFull(Uint8List bytes) {
  final img = decodeImage(bytes)!;
  final gray = grayscale(img);
  return Uint8List.fromList(encodeJpg(gray));
}
```

The UI should instantly display the preview result, giving the illusion of immediate processing, while the high-quality version is computed in parallel or deferred until export.

For resize operations, always downscale before applying transformations. Processing should follow: decode → resize → transform → encode. This reduces CPU load significantly and prevents memory spikes.

For PDF export, the delay is caused by combining large images without compression and doing so on the UI thread. Move PDF generation into an isolate and compress images beforehand. Also provide user feedback via a progress indicator to avoid perceived freezing.

```dart
Uint8List generatePdf(List<Uint8List> images) {
  final pdf = Document();
  for (final imgBytes in images) {
    final img = decodeImage(imgBytes)!;
    final resized = copyResize(img, width: 1000);
    final jpg = encodeJpg(resized);

    pdf.addPage(Page(
      build: (context) => Center(
        child: Image(MemoryImage(jpg)),
      ),
    ));
  }
  return pdf.save();
}

// usage
final pdfBytes = await compute(generatePdf, imageList);
```

To ensure smooth UX, every action must immediately update UI state before processing begins. For example:

```dart
setState(() => isProcessing = true);
final result = await compute(...);
setState(() => isProcessing = false);
```

Additionally, implement a caching layer so repeated operations (like applying the same filter or rotation) do not recompute unnecessarily. Store processed outputs keyed by transformation parameters.

All processing must be memory-aware. Avoid keeping multiple full-resolution images in memory simultaneously. Dispose intermediate objects and prefer Uint8List reuse where possible.

The final system should behave as follows: when the user taps any tool, the UI responds instantly using preview data; the heavy computation runs in parallel; the result replaces the preview seamlessly; export always uses the highest-quality processed data. This ensures the app feels fast, responsive, and comparable to native image editors while maintaining efficient CPU and storage usage.





---

## Native Performance Architecture (Kotlin/Android)

All CPU-intensive image processing now executes on Android's native layer using Kotlin, eliminating main-thread blocking and memory transfer overhead. This ensures true non-blocking responsiveness.

### Key Principles

1. **True Non-Blocking UI**: Buttons NEVER disable during processing. All operations are queued and executed asynchronously on background threads.
2. **Immediate Visual Feedback**: Optimistic UI updates (rotation preview, crop overlay) show instant response while native processing happens in background.
3. **Native Processing**: Crop, rotate, filter, resize, and PDF generation all run in Kotlin using Android APIs (no Dart isolates).
4. **MethodChannel Bridge**: Flutter communicates with Kotlin via MethodChannel for fully async invoke pattern.
5. **Operation Queue**: Dart-side queue prevents overlapping operations and maintains order without blocking UI.

### Architecture Overview

```
User Tap → Optimistic UI Update → Enqueue Operation → UI Remains Interactive
                                            ↓
                                    Dart Operation Queue
                                            ↓
                                    MethodChannel → Kotlin
                                            ↓
                                   Native ImageProcessor
                                            ↓
                        Android Thread Pool (Background)
                                            ↓
                        Return Result → Update UI Seamlessly
```

### Operation Flow

1. **Rotate Operation**:
   - User taps rotate button
   - Optimistic preview shows rotated image immediately (Transform.rotate)
   - UI remains fully responsive
   - Operation enqueued to process queue
   - Native Kotlin processes actual bitmap rotation in background
   - Result replaces preview when ready

2. **Filter Operation**:
   - User taps filter from strip
   - Lo-res preview (600px) generated instantly for immediate feedback
   - Full-res filter applied in background via Kotlin
   - High-quality result replaces preview silently

3. **PDF Export**:
   - User taps Export
   - Export screen shows progress indicator
   - PDF generation runs on Android thread pool in Kotlin
   - Progress callbacks update UI during processing
   - No UI blocking, no ANR risk

###Kotlin Native Processor (`ImageProcessor.kt`)

```kotlin
class ImageProcessor {
    fun processImage(action: String, bytes: ByteArray, params: Map<String, Any>): ByteArray {
        return when (action) {
            "crop" -> crop(bytes, params)
            "rotate" -> rotate(bytes, params)
            "filter" -> applyFilter(bytes, params)
            "resize" -> resize(bytes, params)
            else -> bytes
        }
    }
}
```

All operations are memory-efficient:
- Bitmaps are recycled immediately after use
- Parameters passed as primitives, not full objects
- Output is compressed JPEG to reduce transfer size

### Dart Operation Queue (`OperationQueue`)

```dart
final queue = OperationQueue();

queue.enqueue(
  () => NativeImageProcessor.rotateByDegrees(path, 90),
  label: 'rotate_90'
);
// UI remains interactive immediately
// Operation processes in background sequentially
```

Benefits:
- No blocking awaits on UI thread
- Operations process in order
- Multiple rapid taps are safely queued, not dropped
- UI can show queue status if needed (pending count)

### Result

- ✅ **Instant Button Response**: Buttons always clickable
- ✅ **No UI Freezing**: Even large images process smoothly
- ✅ **Smooth Animations**: Crop overlays, rotations, transitions unaffected
- ✅ **Memory Efficient**: Native bitmaps, no Dart copies
- ✅ **ANR Safe**: All heavy work off main thread


things are littlbit fixed now it giving me fast repsone as normal
just some issue is occured check out the screenshot i have uplaoded
see the issue of it that croping filed is not proepr

one more things to fix that when any flter applied like form none to like pro and after it filter to pro so now it like to show that it is showing that pro verion of is nowe mroe filterable
i am try to say that 
every time when filter applied it will be like fom non to pro and none to enahce so on not like none to pro then enhace that pro verion no

and addon this that on exported is done thne it save this as draft and redirect me back to the home screen






now this is done for now
let make one page called files
it have filter(options) -> soreted by name or date and 
switches button that exported and drafts

and addon the thing that in hold any file to open the option like if draft then it willoepn menu export this scan and sharing option {use icons also}

also add a quick menu below like added signature and other things 
and delete renaming it
edit it
this is for darft files

the exproted has differ menu in that just save to device again open it {it will open it in app only we will be using pdfinum for endering that pdf and if on app opens if you want to on browser then simply the opened pdf on next screen therie will b e 3 dots in that it will show that open in defualt browser}

share it
here also add quick menu
signature renain mg delte and all
this is all for files

and also make that when the there a recent and when click o the arrow it will redirect to the files page


mkaethe pdf viewer inbuilt app only so our exported pdf cna be open via app 
we are makeing one page files in that files adn draft will be there which are exported by app

and addon thing that the outside pdf like we click on it so it option that onpen in drive,other apps, so here you have to make that here our app should also visible and when click so the custom non app pdf should also open