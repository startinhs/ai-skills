package com.bixolon.sample;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Message;
import android.provider.MediaStore;
import android.support.annotation.Nullable;
import android.support.v4.app.Fragment;
import android.text.Layout;
import android.text.method.ScrollingMovementMethod;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.bixolon.sample.PrinterControl.BixolonPrinter;

public class ImageFragment extends Fragment implements View.OnClickListener, SeekBar.OnSeekBarChangeListener, RadioGroup.OnCheckedChangeListener {
    private String PATH = Environment.getExternalStorageDirectory().getAbsolutePath();
    private int REQUEST_CODE_ACTION_PICK = 1;

    private LinearLayout layoutStartEndPage;

    private RadioGroup radioGroupPrintingType;
    private EditText editTextWidth;
    private EditText editTextStartPage;
    private EditText editTextEndPage;
    private TextView textViewBrightness;
    private TextView textViewGrayScale;
    private TextView textViewFilePath;
    private TextView deviceMessagesTextView;
    private SeekBar seekBarBrightness;
    private SeekBar seekBarThres;

    private int spinnerAlignment = 0;
    private int spinnerDither = 0;
    private int spinnerCompress = 0;

    private String[] fileItems = null;

    private Uri uri;
    private int totalPages = 1;

    public static ImageFragment newInstance() {
        ImageFragment fragment = new ImageFragment();
        Bundle args = new Bundle();
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_image, container, false);

        layoutStartEndPage = view.findViewById(R.id.LinearLayout5);
        layoutStartEndPage.setVisibility(View.GONE);

        radioGroupPrintingType = view.findViewById(R.id.radioGroupPrint);
        radioGroupPrintingType.setOnCheckedChangeListener(this);

        view.findViewById(R.id.buttonFileSelect).setOnClickListener(this);
        view.findViewById(R.id.buttonPrint).setOnClickListener(this);
        view.findViewById(R.id.buttonGetWidth).setOnClickListener(this);

        editTextWidth = view.findViewById(R.id.editTextWidth);
        editTextStartPage = view.findViewById(R.id.editTextStartPage);
        editTextEndPage = view.findViewById(R.id.editTextEndPage);
        textViewBrightness = view.findViewById(R.id.textViewBrightness);
        textViewGrayScale = view.findViewById(R.id.textViewThres);
        textViewFilePath = view.findViewById(R.id.textViewFilePath);

        editTextStartPage.setText("1");
        editTextEndPage.setText("1");

        editTextWidth.setText("384");
        textViewBrightness.setText("Brightness : 50");

        deviceMessagesTextView = view.findViewById(R.id.textViewDeviceMessages);
        deviceMessagesTextView.setMovementMethod(new ScrollingMovementMethod());
        deviceMessagesTextView.setVerticalScrollBarEnabled(true);

        Spinner imageAlignment = view.findViewById(R.id.imageAlignment);
        Spinner imageDither = view.findViewById(R.id.imageDither);
        Spinner imageCompress = view.findViewById(R.id.imageCompress);

        ArrayAdapter alignmentAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.Alignment, android.R.layout.simple_spinner_dropdown_item);
        alignmentAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        imageAlignment.setAdapter(alignmentAdapter);
        imageAlignment.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                spinnerAlignment = position;
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        ArrayAdapter ditherAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.Dither, android.R.layout.simple_spinner_dropdown_item);
        ditherAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        imageDither.setAdapter(ditherAdapter);
        imageDither.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                spinnerDither = position;
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        ArrayAdapter CompressAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.Compress, android.R.layout.simple_spinner_dropdown_item);
        CompressAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        imageCompress.setAdapter(CompressAdapter);
        imageCompress.setSelection(1);
        imageCompress.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                spinnerCompress = position;
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        seekBarBrightness = view.findViewById(R.id.seekBarBrightness);
        seekBarBrightness.setOnSeekBarChangeListener(this);

        seekBarThres = view.findViewById(R.id.seekBarThres);

        return view;
    }

    @Override
    public void onViewCreated(View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        seekBarThres.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){

            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                textViewGrayScale.setText("Threshold : " + Integer.toString(progress));
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });
    }

    @Override
    public void onClick(View view) {
        int width = 0, alignment = 0, startPage = 0, endPage = 0, brightness = 0;
        String strPath = "";

        switch (view.getId()) {
            case R.id.buttonFileSelect:
                switch (radioGroupPrintingType.getCheckedRadioButtonId()) {
                    case R.id.radioImage:
                        showGallery();
                        break;
                    case R.id.radioPDF:
                        showPDFFileList();
                        break;
                }
                break;

            case R.id.buttonGetWidth:
                width = MainActivity.getPrinterInstance().getPrinterMaxWidth();
                editTextWidth.setText(Integer.toString(width));
                break;

            case R.id.buttonPrint:
                strPath = textViewFilePath.getText().toString();
                width = Integer.parseInt(editTextWidth.getText().toString());
                brightness = seekBarBrightness.getProgress();

                switch (spinnerAlignment) {
                    case 0:
                        alignment = BixolonPrinter.ALIGNMENT_LEFT;
                        break;
                    case 1:
                        alignment = BixolonPrinter.ALIGNMENT_CENTER;
                        break;
                    case 2:
                        alignment = BixolonPrinter.ALIGNMENT_RIGHT;
                        break;
                    default:
                        alignment = BixolonPrinter.ALIGNMENT_LEFT;
                        break;
                }

                if (width <= 0) {
                    Toast.makeText(getContext(), "Invalid width : " + width, Toast.LENGTH_SHORT).show();
                    break;
                }

                switch (radioGroupPrintingType.getCheckedRadioButtonId()) {
                    case R.id.radioImage:
                        int thres = seekBarThres.getProgress();
                        MainActivity.getPrinterInstance().printImage(strPath, width, alignment, brightness, spinnerDither, spinnerCompress, thres);
                        break;

                    case R.id.radioPDF:
                        if (uri == null) {
                            Toast.makeText(getContext(), "Invalid file path!!", Toast.LENGTH_SHORT).show();
                            break;
                        }

                        if (editTextStartPage.getText().toString().length() != 0 && editTextEndPage.getText().toString().length() != 0) {
                            startPage = Integer.parseInt(editTextStartPage.getText().toString());
                            endPage = Integer.parseInt(editTextEndPage.getText().toString());

                            if (startPage > endPage) {
                                Toast.makeText(getContext(), "check the page", Toast.LENGTH_SHORT).show();
                            } else if (startPage <= 0 || endPage <= 0) {
                                Toast.makeText(getContext(), "check the startpage", Toast.LENGTH_SHORT).show();
                            } else if (endPage > totalPages || startPage > totalPages) {
                                Toast.makeText(getContext(), "check the endpage", Toast.LENGTH_SHORT).show();
                            } else {
                                int bitmapThres = seekBarThres.getProgress();
                                MainActivity.getPrinterInstance().directIO(0, new byte[]{0x08, 0x7f, 0X0A});
                                MainActivity.getPrinterInstance().printPdf(uri, width, alignment, startPage, endPage, brightness, spinnerDither, spinnerCompress, bitmapThres);
                            }
                        }
                        break;
                }
        }
    }

    @Override
    public void onProgressChanged(SeekBar seekBar, int i, boolean b) {
        textViewBrightness.setText("Brightness : " + Integer.toString(i));
    }

    @Override
    public void onStartTrackingTouch(SeekBar seekBar) {

    }

    @Override
    public void onStopTrackingTouch(SeekBar seekBar) {

    }

    @Override
    public void onCheckedChanged(RadioGroup radioGroup, int i) {
        switch (i) {
            case R.id.radioImage:
                layoutStartEndPage.setVisibility(View.GONE);
                break;
            case R.id.radioPDF:
                layoutStartEndPage.setVisibility(View.VISIBLE);
                break;
        }

        textViewFilePath.setText("");
    }

    private void showPDFFileList() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.setType("application/pdf");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(Intent.createChooser(intent, "Select PDF"), REQUEST_CODE_ACTION_PICK);
    }

    private void showGallery() {
        String externalStorageState = Environment.getExternalStorageState();

        if (externalStorageState.equals(Environment.MEDIA_MOUNTED)) {
            Intent intent = new Intent(Intent.ACTION_PICK);
            intent.setType(android.provider.MediaStore.Images.Media.CONTENT_TYPE);
            startActivityForResult(intent, REQUEST_CODE_ACTION_PICK);
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_ACTION_PICK) {
            if (data != null) {
                uri = data.getData();
                ContentResolver cr = getActivity().getContentResolver();
                Cursor c = cr.query(uri, new String[]{MediaStore.Images.Media.DATA}, null, null, null);
                if (c == null || c.getCount() == 0) {
                    return;
                }

                c.moveToFirst();
                int columnIndex = c.getColumnIndexOrThrow(MediaStore.Images.Media.DATA);
                String text = c.getString(columnIndex);

                textViewFilePath.setText(text);
            }
        }
    }

    public void setDeviceLog(String data) {
        mHandler.obtainMessage(0, 0, 0, data).sendToTarget();
    }

    public final Handler mHandler = new Handler(new Handler.Callback() {
        @SuppressWarnings("unchecked")
        @Override
        public boolean handleMessage(Message msg) {
            switch (msg.what) {
                case 0:
                    deviceMessagesTextView.append((String) msg.obj + "\n");

                    Layout layout = deviceMessagesTextView.getLayout();
                    if (layout != null) {
                        int y = layout.getLineTop(
                                deviceMessagesTextView.getLineCount()) - deviceMessagesTextView.getHeight();
                        if (y > 0) {
                            deviceMessagesTextView.scrollTo(0, y);
                            deviceMessagesTextView.invalidate();
                        }
                    }
                    break;
            }
            return false;
        }
    });
}
