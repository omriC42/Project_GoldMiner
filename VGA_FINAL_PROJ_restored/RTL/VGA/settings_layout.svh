// settings_layout.svh - WRITTEN BY make_menu_pictures.py, do not edit by hand.
// Where the rows and the value words of settings_screen.png are ON THE SCREEN (640x480).
// The text is 28 screen pixels high (7 font rows x 4).
localparam int SET_ROWS   = 4;
localparam int SET_TEXT_H = 28;
localparam int SET_ARROW_X = 8;            // left edge of the cursor arrow (16 wide, at the LABEL line)
localparam int SET_LABEL_DY = 36;          // the label line is this much above the values line
localparam int SET_ROW_Y [0:3] = '{120, 200, 280, 360};   // top of the VALUES line of each row
localparam int SET_NUM_VALUES [0:3] = '{3, 3, 2, 2};
localparam int SET_VAL_X0 [0:3][0:2] = '{'{80, 204, 376}, '{80, 204, 328}, '{80, 156, 0}, '{80, 156, 0}};   // value words: left edge
localparam int SET_VAL_X1 [0:3][0:2] = '{'{172, 344, 468}, '{172, 296, 420}, '{124, 224, 0}, '{124, 224, 0}};   // value words: right edge (excluded)
