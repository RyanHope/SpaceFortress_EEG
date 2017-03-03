import os
import h5py
import numpy as np
from keras.preprocessing.image import ImageDataGenerator
from keras import optimizers
from keras.models import Sequential
from keras.layers import Convolution2D, MaxPooling2D, ZeroPadding2D
from keras.layers import Activation, Dropout, Flatten, Dense
from keras.callbacks import ModelCheckpoint

img_width, img_height = 32, 32

sid = 1
alias = "features4"

train_data_dir = '../%s/subject%d/train' % (alias, sid)
validation_data_dir = '../%s/subject%d/test' % (alias, sid)
nb_train_samples = 6000
nb_validation_samples = 1400
nb_epoch = 100000

# classes = [
#     "explode-smallhex", "fortress-destroyed", "fortress-respawn", "hold-fire",
#     "hold-thrust", "shell-hit-ship", "ship-respawn", "vlner-increased", "fortress-fired"
# ]
classes = ["hold-fire", "hold-thrust"]

input_shape = (3, img_width, img_height)

# Create Bashivan (2016) Model

model = Sequential()

model.add(ZeroPadding2D((1, 1), input_shape=input_shape))
model.add(Convolution2D(32, 3, 3, activation='relu', name='conv1_1'))
model.add(ZeroPadding2D((1, 1)))
model.add(Convolution2D(32, 3, 3, activation='relu', name='conv1_2'))
model.add(ZeroPadding2D((1, 1)))
model.add(Convolution2D(32, 3, 3, activation='relu', name='conv1_3'))
model.add(ZeroPadding2D((1, 1)))
model.add(Convolution2D(32, 3, 3, activation='relu', name='conv1_4'))
model.add(MaxPooling2D((2, 2), strides=(2, 2)))

model.add(ZeroPadding2D((1, 1), input_shape=(3, img_width, img_height)))
model.add(Convolution2D(64, 3, 3, activation='relu', name='conv2_1'))
model.add(ZeroPadding2D((1, 1)))
model.add(Convolution2D(64, 3, 3, activation='relu', name='conv2_2'))
model.add(MaxPooling2D((2, 2), strides=(2, 2)))

model.add(ZeroPadding2D((1, 1)))
model.add(Convolution2D(128, 3, 3, activation='relu', name='conv3_1'))
model.add(MaxPooling2D((2, 2), strides=(2, 2)))

top_model = Sequential()
top_model.add(Flatten(input_shape=model.output_shape[1:]))
top_model.add(Dense(512, activation='relu'))
top_model.add(Dropout(0.5))
top_model.add(Dense(len(classes), activation='softmax'))

model.add(top_model)

class_mode = "categorical"
if class_mode == "categorical":
    loss = "categorical_crossentropy"
elif class_mode == "binary":
    loss = "binary_crossentropy"
elif class_mode == "sparse":
    loss = "sparse_categorical_crossentropy"

model.compile(loss=loss,
              optimizer=optimizers.Adadelta(lr=100),
              metrics=['accuracy'])

filepath="subject%d_weights_improvement_3_{epoch:04d}_{val_acc:.4f}.hdf5" % (sid)
checkpoint = ModelCheckpoint(filepath, monitor='val_acc', verbose=2, save_best_only=True, mode='max')
callbacks_list = [checkpoint]

datagen = ImageDataGenerator()

batch_size = 200

train_generator = datagen.flow_from_directory(
        train_data_dir,
        target_size=(img_height, img_width),
        shuffle=True,
        batch_size=batch_size,
        class_mode=class_mode,
        classes=classes)

validation_generator = datagen.flow_from_directory(
        validation_data_dir,
        target_size=(img_height, img_width),
        shuffle=True,
        batch_size=batch_size,
        class_mode=class_mode,
        classes=classes)

model.fit_generator(
        train_generator,
        samples_per_epoch=nb_train_samples,
        nb_epoch=nb_epoch,
        validation_data=validation_generator,
        nb_val_samples=nb_validation_samples,
        callbacks=callbacks_list)
