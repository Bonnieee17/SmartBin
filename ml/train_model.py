import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import os

# 1. Configuration
DATASET_DIR = 'ml/dataset'
MODEL_EXPORT_PATH = 'assets/waste_classifier.tflite'
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 8 # Small batch for small dataset
EPOCHS = 20

def train_model():
    print("Loading dataset and applying augmentation...")

    # Data Augmentation to help with small dataset
    datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=20,
        width_shift_range=0.2,
        height_shift_range=0.2,
        horizontal_flip=True,
        validation_split=0.2
    )

    train_generator = datagen.flow_from_directory(
        DATASET_DIR,
        target_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        class_mode='binary',
        subset='training'
    )

    validation_generator = datagen.flow_from_directory(
        DATASET_DIR,
        target_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        class_mode='binary',
        subset='validation'
    )

    # 2. Build Model (Transfer Learning with MobileNetV2)
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )
    base_model.trainable = False

    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dense(1, activation='sigmoid')
    ])

    model.compile(
        optimizer='adam',
        loss='binary_crossentropy',
        metrics=['accuracy']
    )

    # 3. Train
    print("Starting training...")
    model.fit(
        train_generator,
        epochs=EPOCHS,
        validation_data=validation_generator
    )

    # 4. Export to TFLite
    print(f"Exporting model to {MODEL_EXPORT_PATH}...")

    # Ensure assets directory exists
    if not os.path.exists('assets'):
        os.makedirs('assets')

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()

    with open(MODEL_EXPORT_PATH, 'wb') as f:
        f.write(tflite_model)

    print("Success! TFLite model generated.")

if __name__ == "__main__":
    train_model()
