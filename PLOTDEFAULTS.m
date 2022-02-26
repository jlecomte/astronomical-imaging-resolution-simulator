xlabel('Pixels');
ylabel('Intensity profile');
axis([-PIXEL_SIZE * PIXEL_COUNT / 2, PIXEL_SIZE * PIXEL_COUNT / 2, 0, 1], 'ticx', 'nolabel');
set(gca, 'xtick', -PIXEL_SIZE * PIXEL_COUNT / 2 : PIXEL_SIZE : PIXEL_SIZE * PIXEL_COUNT / 2);
